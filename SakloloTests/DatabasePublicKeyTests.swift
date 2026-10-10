import CryptoKit
import Foundation
import XCTest
@testable import Saklolo

final class DatabasePublicKeyTests: XCTestCase {
    private func write(_ text: String) throws -> URL {
        let url = try DatabaseFixtures.temporaryDirectory(self).appendingPathComponent("database-public-key.txt")
        try Data(text.utf8).write(to: url)
        return url
    }

    /// Until Jayson runs keygen and commits the key, the app has none, so the
    /// updater is never built and no request is made.
    @MainActor
    func testTheAppShipsWithoutAKeyForNow() {
        XCTAssertNil(DatabasePublicKey.bundled())
        XCTAssertNil(DatabaseUpdater.shared)
    }

    func testAMissingFileGivesNoKey() throws {
        let url = try DatabaseFixtures.temporaryDirectory(self).appendingPathComponent("absent.txt")
        XCTAssertNil(DatabasePublicKey.load(from: url))
    }

    func testABase64RawKeyLoads() throws {
        let key = Curve25519.Signing.PrivateKey().publicKey
        let url = try write(key.rawRepresentation.base64EncodedString() + "\n")

        XCTAssertEqual(DatabasePublicKey.load(from: url)?.rawRepresentation, key.rawRepresentation)
    }

    func testGarbageGivesNoKey() throws {
        XCTAssertNil(DatabasePublicKey.load(from: try write("not a key")))
        XCTAssertNil(DatabasePublicKey.load(from: try write(Data(count: 16).base64EncodedString())), "wrong length")
    }
}
