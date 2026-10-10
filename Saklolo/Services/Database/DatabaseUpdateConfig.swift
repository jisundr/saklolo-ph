import Foundation

/// Where updates come from and how the request is made. Published by
/// committing `database/database.json` and its `.sig` together to `main`
/// (`tools/dbtool.sh sign`); see docs/DATABASE-UPDATES.md.
///
/// The request carries nothing about the person or the phone: a plain GET of
/// a fixed URL, no query, no body, no cookies, no identifier, and a fixed
/// User-Agent in place of the default one (which names the OS and build).
enum DatabaseUpdateConfig {
    static let databaseURL = URL(string: "https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json")!
    static let signatureURL = URL(string: "https://raw.githubusercontent.com/jisundr/saklolo-ph/main/database/database.json.sig")!

    /// A database file is a few KB; anything past this is not one.
    static let maxResponseBytes = 256 * 1024
    /// Between completed checks.
    static let minInterval: TimeInterval = 6 * 60 * 60
    /// Between attempts, so a failing network cannot make the check loop.
    static let retryInterval: TimeInterval = 60
    /// A whole check gives up after this, whatever the network does.
    static let hardBound: Duration = .seconds(20)
    static let lastCompletedCheckKey = "database.lastCompletedCheck"

    static let headers = ["Accept": "application/json", "User-Agent": "Saklolo"]

    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        return request
    }

    /// No cookies, no URL cache, no stored credentials.
    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 20
        configuration.httpAdditionalHeaders = headers
        return configuration
    }
}

/// One GET. The app uses `URLSessionDatabaseFetcher`; tests pass a fake, so
/// no test touches the network.
protocol DatabaseFetching: Sendable {
    func fetch(_ request: URLRequest) async throws -> Data
}

struct URLSessionDatabaseFetcher: DatabaseFetching {
    struct Refused: Error {}

    private let session = URLSession(configuration: DatabaseUpdateConfig.sessionConfiguration())

    /// HTTPS and status 200 only; stops reading past `maxResponseBytes`.
    func fetch(_ request: URLRequest) async throws -> Data {
        guard request.url?.scheme == "https" else { throw Refused() }
        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              response.expectedContentLength <= Int64(DatabaseUpdateConfig.maxResponseBytes) else { throw Refused() }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > DatabaseUpdateConfig.maxResponseBytes { throw Refused() }
        }
        return data
    }
}
