import CryptoKit
import Foundation
import XCTest
@testable import Saklolo

/// Database files for tests, built from the bundled `database.json` so a
/// test only states the one thing it changes.
enum DatabaseFixtures {
    /// The shipped file's exact bytes. The tests are hosted by the app, so
    /// `Bundle.main` is the shipped bundle.
    static func bundledData() throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "database", withExtension: "json"), "database.json is not in the app bundle")
        return try Data(contentsOf: url)
    }

    static func bundled() throws -> FirstAidDatabase {
        try JSONDecoder().decode(FirstAidDatabase.self, from: bundledData())
    }

    /// The bundled database with `change` applied, encoded.
    static func data(_ change: (inout FirstAidDatabase) -> Void) throws -> Data {
        var database = try bundled()
        change(&database)
        return try JSONEncoder().encode(database)
    }

    static func index(of id: String, in database: FirstAidDatabase) -> Int {
        database.scripts.firstIndex { $0.id == id }!
    }

    /// The bundled database at `version`, with `change` applied.
    static func data(version: Int, _ change: (inout FirstAidDatabase) -> Void = { _ in }) throws -> Data {
        try data { database in
            database.version = version
            change(&database)
        }
    }

    /// A `.sig` file's contents: base64 of the Ed25519 signature, newline-terminated
    /// like the publishing tool writes it.
    static func sign(_ payload: Data, with key: Curve25519.Signing.PrivateKey) throws -> Data {
        Data((try key.signature(for: payload).base64EncodedString() + "\n").utf8)
    }

    /// A fresh empty directory for one test's cache, removed at teardown.
    static func temporaryDirectory(_ test: XCTestCase) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("saklolo-db-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        test.addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
