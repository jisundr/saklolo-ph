import CryptoKit
import Foundation
import XCTest
@testable import Saklolo

/// The classifier and the guide follow a verified update. Uses its own store
/// (temp cache, throwaway key), never `DatabaseStore.shared`.
final class DatabaseReadersTests: XCTestCase {
    private let key = Curve25519.Signing.PrivateKey()

    private func makeStore() throws -> DatabaseStore {
        DatabaseStore(cache: DatabaseCache(directory: try DatabaseFixtures.temporaryDirectory(self)), publicKey: key.publicKey)
    }

    /// Version 2: "napaso" (not in the bundle) leads to bleeding, and the
    /// fall script's last step is reworded.
    private func applyUpdate(to store: DatabaseStore) throws {
        let payload = try DatabaseFixtures.data(version: 2) { db in
            db.scripts[DatabaseFixtures.index(of: "bleeding", in: db)].keywords.append("napaso")
            let fall = DatabaseFixtures.index(of: "fall", in: db)
            db.scripts[fall].steps[db.scripts[fall].steps.count - 1] = "Stay with them until help arrives."
        }
        let result = store.apply(payload: payload, signature: try DatabaseFixtures.sign(payload, with: key), publicKey: key.publicKey)
        XCTAssertEqual(result, .applied(2))
    }

    func testTheClassifierUsesTheUpdatedKeywords() throws {
        let store = try makeStore()
        XCTAssertEqual(SituationClassifierService(keywords: store.active.keywords).classifyByKeyword(transcript: "napaso si Lola").scriptID, "general")

        try applyUpdate(to: store)

        XCTAssertEqual(SituationClassifierService(keywords: store.active.keywords).classifyByKeyword(transcript: "napaso si Lola").scriptID, "bleeding")
    }

    func testTheGuideUsesTheUpdatedSteps() throws {
        let store = try makeStore()
        try applyUpdate(to: store)

        XCTAssertEqual(store.script(id: "fall")?.steps.last, "Stay with them until help arrives.")
    }

    func testAnOpenGuideKeepsTheStepsItOpenedWith() throws {
        let store = try makeStore()
        let open = try XCTUnwrap(store.script(id: "fall"))
        let before = open.steps

        try applyUpdate(to: store)

        XCTAssertEqual(open.steps, before)
        XCTAssertNotEqual(store.script(id: "fall")?.steps, before)
    }
}
