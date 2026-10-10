import CryptoKit
import Foundation
import XCTest
@testable import Saklolo

/// Keys here are throwaway, generated per test; no real signing key is
/// involved anywhere in the tests.
final class DatabaseStoreTests: XCTestCase {
    private let key = Curve25519.Signing.PrivateKey()
    private var publicKey: Curve25519.Signing.PublicKey { key.publicKey }
    private var cache: DatabaseCache!

    override func setUpWithError() throws {
        cache = DatabaseCache(directory: try DatabaseFixtures.temporaryDirectory(self))
    }

    private func makeStore() -> DatabaseStore {
        DatabaseStore(cache: cache, publicKey: publicKey)
    }

    private func cacheBytes() -> Data? {
        try? Data(contentsOf: cache.fileURL)
    }

    /// Feeds `payload` to a store and checks nothing changed: the bundle is
    /// still in use and no cache file was written.
    private func assertIgnored(_ payload: Data, signature: Data? = nil, expected: DatabaseStore.ApplyResult,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let store = makeStore()
        let result = store.apply(payload: payload, signature: try signature ?? DatabaseFixtures.sign(payload, with: key), publicKey: publicKey)

        XCTAssertEqual(result, expected, file: file, line: line)
        XCTAssertEqual(store.active.version, 1, file: file, line: line)
        XCTAssertNil(cacheBytes(), "cache was written", file: file, line: line)
        XCTAssertEqual(makeStore().active.version, 1, "a new store picked something up", file: file, line: line)
    }

    // MARK: Bundle only

    func testWithNoCacheTheBundleIsUsed() throws {
        let store = makeStore()
        XCTAssertEqual(store.active.version, 1)
        XCTAssertEqual(store.script(id: "fall")?.steps, try DatabaseFixtures.bundled().scripts.first { $0.id == "fall" }?.steps)
    }

    func testAnUnknownScriptIdFallsBackToGeneral() {
        XCTAssertEqual(makeStore().script(id: "burn")?.id, "general")
    }

    func testWithoutAUsableBundleTheBuiltInKeywordsStillWork() {
        let store = DatabaseStore(bundled: nil, cache: cache, publicKey: publicKey)
        XCTAssertEqual(store.active.keywords.match("nahulog si Lola"), "fall")
        XCTAssertNil(store.script(id: "fall"))
    }

    // MARK: Rejected updates

    func testAnUnsignedUpdateIsIgnored() throws {
        try assertIgnored(DatabaseFixtures.data(version: 2), signature: Data(), expected: .rejected(.badSignature))
    }

    func testAnUpdateSignedByAnotherKeyIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        let other = try DatabaseFixtures.sign(payload, with: Curve25519.Signing.PrivateKey())
        try assertIgnored(payload, signature: other, expected: .rejected(.badSignature))
    }

    func testATamperedUpdateIsIgnored() throws {
        var payload = try DatabaseFixtures.data(version: 2)
        let signature = try DatabaseFixtures.sign(payload, with: key)
        let index = try XCTUnwrap(payload.firstIndex(of: UInt8(ascii: "2")))
        payload[index] = UInt8(ascii: "9")
        try assertIgnored(payload, signature: signature, expected: .rejected(.badSignature))
    }

    func testASignatureThatIsNotBase64IsIgnored() throws {
        try assertIgnored(DatabaseFixtures.data(version: 2), signature: Data("not a signature".utf8), expected: .rejected(.badSignature))
    }

    func testSignedMalformedJSONIsIgnored() throws {
        try assertIgnored(Data("{\"version\": 2, \"scripts\": [".utf8), expected: .rejected(.malformed))
    }

    func testASignedUpdateWithEmptyKeywordsIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts[DatabaseFixtures.index(of: "fall", in: $0)].keywords = [] }
        try assertIgnored(payload, expected: .rejected(.noKeywords("fall")))
    }

    func testASignedUpdateWithTwoStepsIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { db in
            let i = DatabaseFixtures.index(of: "fall", in: db)
            db.scripts[i].steps = Array(db.scripts[i].steps.prefix(2))
        }
        try assertIgnored(payload, expected: .rejected(.stepCount("fall")))
    }

    func testASignedUpdateWithSevenStepsIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts[DatabaseFixtures.index(of: "head_injury", in: $0)].steps.append("Stay with them.") }
        try assertIgnored(payload, expected: .rejected(.stepCount("head_injury")))
    }

    func testASignedUpdateWithANonIFRCSourceIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts[DatabaseFixtures.index(of: "bleeding", in: $0)].source = "A blog post" }
        try assertIgnored(payload, expected: .rejected(.badSource("bleeding")))
    }

    func testASignedUpdateWithACountingStepIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts[DatabaseFixtures.index(of: "unconscious", in: $0)].steps[4] = "Push and count each one." }
        try assertIgnored(payload, expected: .rejected(.countingStep("unconscious")))
    }

    func testASignedUpdateWithoutGeneralIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts.removeAll { $0.id == "general" } }
        try assertIgnored(payload, expected: .rejected(.missingScript("general")))
    }

    func testASignedUpdateWithTheSameVersionAsTheBundleIsIgnored() throws {
        try assertIgnored(DatabaseFixtures.data(version: 1), expected: .notNewer)
    }

    func testAnEqualOrOlderUpdateDoesNotReplaceANewerOne() throws {
        let store = makeStore()
        let v3 = try DatabaseFixtures.data(version: 3)
        XCTAssertEqual(store.apply(payload: v3, signature: try DatabaseFixtures.sign(v3, with: key), publicKey: publicKey), .applied(3))
        let saved = cacheBytes()

        for version in [3, 2] {
            let payload = try DatabaseFixtures.data(version: version) { $0.scripts[0].title = "Changed" }
            let result = store.apply(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key), publicKey: publicKey)
            XCTAssertEqual(result, .notNewer, "version \(version)")
        }
        XCTAssertEqual(store.active.version, 3)
        XCTAssertNotEqual(store.active.database?.scripts[0].title, "Changed")
        XCTAssertEqual(cacheBytes(), saved)
    }

    // MARK: Accepted update

    func testANewerSignedUpdateIsUsedAndSurvivesARestart() throws {
        let payload = try DatabaseFixtures.data(version: 2) { $0.scripts[DatabaseFixtures.index(of: "fall", in: $0)].title = "Fell down" }
        let store = makeStore()

        XCTAssertEqual(store.apply(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key), publicKey: publicKey), .applied(2))
        XCTAssertEqual(store.active.version, 2)
        XCTAssertEqual(store.active.title(id: "fall"), "Fell down")

        let restarted = makeStore()
        XCTAssertEqual(restarted.active.version, 2)
        XCTAssertEqual(restarted.active.title(id: "fall"), "Fell down")
    }

    /// `SakloloTests/Fixtures/test-only-*` were made by `tools/dbtool.sh`
    /// with a throwaway key that was deleted straight after (test-only; it
    /// signs nothing the app ships). Proves the tool and the app agree on the
    /// file and signature format.
    func testAFileSignedByThePublishingToolIsAccepted() throws {
        let fixtures = Bundle(for: Self.self)
        let payload = try Data(contentsOf: try XCTUnwrap(fixtures.url(forResource: "test-only-database-v2", withExtension: "json")))
        let signature = try Data(contentsOf: try XCTUnwrap(fixtures.url(forResource: "test-only-database-v2.json", withExtension: "sig")))
        let toolKey = try XCTUnwrap(DatabasePublicKey.load(from: try XCTUnwrap(fixtures.url(forResource: "test-only-public-key", withExtension: "txt"))))
        let store = DatabaseStore(cache: cache, publicKey: toolKey)

        XCTAssertEqual(store.apply(payload: payload, signature: signature, publicKey: toolKey), .applied(2))
        XCTAssertEqual(store.active.database?.scripts, try DatabaseFixtures.bundled().scripts, "same content, new version")
    }

    // MARK: Bad cache on disk

    private func writeCacheFile(_ bytes: Data) throws {
        try FileManager.default.createDirectory(at: cache.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: cache.fileURL)
    }

    func testCorruptCacheBytesFallBackToTheBundle() throws {
        try writeCacheFile(Data([0xFF, 0x00, 0x13]))
        XCTAssertEqual(makeStore().active.version, 1)
    }

    func testATruncatedCacheFallsBackToTheBundle() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        try cache.write(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key))
        let full = try XCTUnwrap(cacheBytes())
        try writeCacheFile(full.prefix(full.count / 2))

        XCTAssertEqual(makeStore().active.version, 1)
    }

    func testACacheWithAWrongSignatureFallsBackToTheBundle() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        try cache.write(payload: payload, signature: try DatabaseFixtures.sign(payload, with: Curve25519.Signing.PrivateKey()))
        XCTAssertEqual(makeStore().active.version, 1)
    }

    func testACacheOlderThanTheBundleIsIgnored() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        try cache.write(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key))
        var newerBundle = try DatabaseFixtures.bundled()
        newerBundle.version = 3

        XCTAssertEqual(DatabaseStore(bundled: newerBundle, cache: cache, publicKey: publicKey).active.version, 3)
    }

    func testWithoutAPublicKeyTheCacheIsNotTrusted() throws {
        let payload = try DatabaseFixtures.data(version: 2)
        try cache.write(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key))
        XCTAssertEqual(DatabaseStore(cache: cache, publicKey: nil).active.version, 1)
    }
}
