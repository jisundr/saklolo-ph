import CryptoKit
import Foundation
import XCTest
@testable import Saklolo

/// Answers by URL and records every request. Never touches the network.
final class FakeFetcher: DatabaseFetching, @unchecked Sendable {
    enum Answer {
        case body(Data)
        case failure
        /// Answers only after `seconds` and never notices cancellation.
        case stall(seconds: TimeInterval)
    }

    private let lock = NSLock()
    private var answers: [URL: Answer] = [:]
    private var recorded: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { recorded } }

    func answer(_ url: URL, with answer: Answer) {
        lock.withLock { answers[url] = answer }
    }

    func fetch(_ request: URLRequest) async throws -> Data {
        let answer: Answer? = lock.withLock {
            recorded.append(request)
            return request.url.flatMap { answers[$0] }
        }
        switch answer {
        case .body(let data): return data
        case .stall(let seconds):
            return await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { continuation.resume(returning: Data()) }
            }
        case .failure, nil: throw URLError(.notConnectedToInternet)
        }
    }
}

@MainActor
final class DatabaseUpdaterTests: XCTestCase {
    private let key = Curve25519.Signing.PrivateKey()
    private var store: DatabaseStore!
    private var fetcher: FakeFetcher!
    private var signal: SignalSwitch!
    private var defaults: UserDefaults!
    private var time = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        store = DatabaseStore(cache: DatabaseCache(directory: try DatabaseFixtures.temporaryDirectory(self)), publicKey: key.publicKey)
        fetcher = FakeFetcher()
        signal = SignalSwitch(on: true)
        let suite = "saklolo-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
    }

    private func makeUpdater(withKey: Bool = true, hardBound: Duration = .seconds(5)) -> DatabaseUpdater {
        DatabaseUpdater(
            fetcher: fetcher,
            store: store,
            publicKey: withKey ? key.publicKey : nil,
            signal: signal,
            now: { [unowned self] in self.time },
            defaults: defaults,
            hardBound: hardBound
        )
    }

    /// Serves a signed version 2 of the bundled database.
    private func publishVersion2() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        fetcher.answer(DatabaseUpdateConfig.databaseURL, with: .body(payload))
        fetcher.answer(DatabaseUpdateConfig.signatureURL, with: .body(try DatabaseFixtures.sign(payload, with: key)))
    }

    private var lastCompletedCheck: Date? {
        defaults.object(forKey: DatabaseUpdateConfig.lastCompletedCheckKey) as? Date
    }

    func testANewerSignedDatabaseIsFetchedAndApplied() async throws {
        try publishVersion2()
        await makeUpdater().checkNow()

        XCTAssertEqual(store.active.version, 2)
        XCTAssertEqual(lastCompletedCheck, time)
    }

    func testNoSignalMeansNoRequest() async throws {
        try publishVersion2()
        signal.hasSignal = false
        await makeUpdater().checkNow()

        XCTAssertTrue(fetcher.requests.isEmpty)
        XCTAssertEqual(store.active.version, 1)
    }

    func testNoPublicKeyMeansNoRequest() async throws {
        try publishVersion2()
        await makeUpdater(withKey: false).checkNow()

        XCTAssertTrue(fetcher.requests.isEmpty)
    }

    func testChecksAreAtMostEverySixHours() async throws {
        try publishVersion2()
        let updater = makeUpdater()
        await updater.checkNow()
        XCTAssertEqual(fetcher.requests.count, 2)

        time += 5 * 60 * 60
        await updater.checkNow()
        XCTAssertEqual(fetcher.requests.count, 2, "inside six hours")

        time += 60 * 60 + 1
        await updater.checkNow()
        XCTAssertEqual(fetcher.requests.count, 4, "after six hours")
    }

    func testAFailedFetchIsSilentAndRetriedLater() async throws {
        fetcher.answer(DatabaseUpdateConfig.databaseURL, with: .failure)
        let updater = makeUpdater()
        await updater.checkNow()

        XCTAssertEqual(store.active.version, 1)
        XCTAssertNil(lastCompletedCheck, "a failure is not a completed check")
        XCTAssertFalse(updater.isChecking)

        await updater.checkNow()
        XCTAssertEqual(fetcher.requests.count, 1, "no retry inside a minute")

        try publishVersion2()
        time += 61
        await updater.checkNow()
        XCTAssertEqual(store.active.version, 2)
    }

    func testAnOversizedBodyIsRejected() async throws {
        fetcher.answer(DatabaseUpdateConfig.databaseURL, with: .body(Data(count: DatabaseUpdateConfig.maxResponseBytes + 1)))
        fetcher.answer(DatabaseUpdateConfig.signatureURL, with: .body(Data()))
        await makeUpdater().checkNow()

        XCTAssertEqual(store.active.version, 1)
        XCTAssertNil(lastCompletedCheck)
    }

    func testABadlySignedDownloadIsIgnoredButCountsAsACheck() async throws {
        let payload = try DatabaseFixtures.data(version: 2)
        fetcher.answer(DatabaseUpdateConfig.databaseURL, with: .body(payload))
        fetcher.answer(DatabaseUpdateConfig.signatureURL, with: .body(try DatabaseFixtures.sign(payload, with: Curve25519.Signing.PrivateKey())))
        await makeUpdater().checkNow()

        XCTAssertEqual(store.active.version, 1)
        XCTAssertEqual(lastCompletedCheck, time)
    }

    /// The alert path never waits on a check: trigger returns at once, a
    /// classification still lands on its own deadline, and a stalled fetch is
    /// dropped by the hard bound.
    func testAStalledFetchDoesNotHoldUpTheAlert() async throws {
        fetcher.answer(DatabaseUpdateConfig.databaseURL, with: .stall(seconds: 3))
        let updater = makeUpdater(hardBound: .milliseconds(300))

        let triggered = Date()
        updater.trigger()
        XCTAssertLessThan(Date().timeIntervalSince(triggered), 0.1)
        XCTAssertTrue(updater.isChecking)

        var service = SituationClassifierService(keywords: store.active.keywords)
        service.model = { _ in
            await withCheckedContinuation { (continuation: CheckedContinuation<SituationClassification?, Never>) in
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { continuation.resume(returning: nil) }
            }
        }
        let started = Date()
        let result = await service.classify(transcript: "Tulong, nahulog si Lola", timeout: .milliseconds(200))
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
        XCTAssertEqual(result.scriptID, "fall")

        let deadline = Date().addingTimeInterval(2)
        while updater.isChecking, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(updater.isChecking, "the hard bound frees the check")
        XCTAssertNil(lastCompletedCheck)
    }

    // MARK: Request privacy

    func testTheRequestsCarryNothingButTheFixedURLsAndHeaders() async throws {
        try publishVersion2()
        await makeUpdater().checkNow()

        let requests = fetcher.requests
        XCTAssertEqual(requests.map(\.url), [DatabaseUpdateConfig.databaseURL, DatabaseUpdateConfig.signatureURL])
        XCTAssertEqual(requests.map(\.url?.absoluteString), [
            "https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json",
            "https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json.sig",
        ])
        for request in requests {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.httpBodyStream)
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.allHTTPHeaderFields, ["Accept": "application/json", "User-Agent": "Saklolo"])
            XCTAssertFalse(request.httpShouldHandleCookies)
        }
    }

    func testTheSessionKeepsNoCookiesCacheOrCredentials() {
        let configuration = DatabaseUpdateConfig.sessionConfiguration()

        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.httpAdditionalHeaders as? [String: String], ["Accept": "application/json", "User-Agent": "Saklolo"])
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 10)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 20)
    }

    func testTheProductionFetcherRefusesPlainHTTPWithoutConnecting() async {
        let request = URLRequest(url: URL(string: "http://127.0.0.1:9/database.json")!)
        do {
            _ = try await URLSessionDatabaseFetcher().fetch(request)
            XCTFail("plain HTTP was fetched")
        } catch {
            XCTAssertTrue(error is URLSessionDatabaseFetcher.Refused)
        }
    }
}
