import Foundation
import XCTest
@testable import Saklolo

final class DatabaseValidatorTests: XCTestCase {
    private func validate(_ change: (inout FirstAidDatabase) -> Void) throws -> Result<FirstAidDatabase, DatabaseRejection> {
        FirstAidDatabaseValidator.validate(try DatabaseFixtures.data(change))
    }

    private func assertRejected(_ expected: DatabaseRejection, file: StaticString = #filePath, line: UInt = #line,
                                _ change: (inout FirstAidDatabase) -> Void) throws {
        switch try validate(change) {
        case .success: XCTFail("accepted, expected \(expected)", file: file, line: line)
        case .failure(let rejection): XCTAssertEqual(rejection, expected, file: file, line: line)
        }
    }

    private func edit(_ id: String, _ change: @escaping (inout FirstAidDatabase.Script) -> Void) -> (inout FirstAidDatabase) -> Void {
        { database in change(&database.scripts[DatabaseFixtures.index(of: id, in: database)]) }
    }

    func testTheBundledDatabasePasses() throws {
        let database = try FirstAidDatabaseValidator.validate(DatabaseFixtures.bundledData()).get()
        XCTAssertEqual(database.version, 1)
        XCTAssertEqual(Set(database.scripts.map(\.id)), ["general", "bleeding", "fall", "head_injury", "unconscious"])
    }

    func testMalformedJSONIsRejected() {
        let result = FirstAidDatabaseValidator.validate(Data("{\"version\": 2, \"scripts\": [".utf8))
        XCTAssertEqual(result, .failure(.malformed))
    }

    func testAMissingFieldIsMalformed() throws {
        let data = Data(#"{"version": 2, "scripts": [{"id": "fall", "title": "Fall"}]}"#.utf8)
        XCTAssertEqual(FirstAidDatabaseValidator.validate(data), .failure(.malformed))
    }

    func testVersionZeroIsRejected() throws {
        try assertRejected(.badVersion) { $0.version = 0 }
    }

    func testADuplicateScriptIsRejected() throws {
        try assertRejected(.duplicateScript("fall")) { $0.scripts.append($0.scripts[DatabaseFixtures.index(of: "fall", in: $0)]) }
    }

    func testADuplicateOfAnUnknownIdIsDroppedNotRejected() throws {
        let database = try validate { database in
            var extra = database.scripts[DatabaseFixtures.index(of: "fall", in: database)]
            extra.id = "choking"
            database.scripts += [extra, extra]
        }.get()

        XCTAssertFalse(database.scripts.contains { $0.id == "choking" })
    }

    func testAKeywordWithTooFewLettersIsRejected() throws {
        for keyword in ["!!!", "a", "ab", "  "] {
            try assertRejected(.noKeywords("fall")) { database in
                database.scripts[DatabaseFixtures.index(of: "fall", in: database)].keywords.append(keyword)
            }
        }
    }

    func testAFileWithoutGeneralIsRejected() throws {
        try assertRejected(.missingScript("general")) { $0.scripts.removeAll { $0.id == "general" } }
    }

    func testAFileMissingAKnownScriptIsRejected() throws {
        try assertRejected(.missingScript("bleeding")) { $0.scripts.removeAll { $0.id == "bleeding" } }
    }

    func testAScriptWithNoKeywordsIsRejected() throws {
        try assertRejected(.noKeywords("bleeding"), edit("bleeding") { $0.keywords = [] })
    }

    func testABlankKeywordIsRejected() throws {
        try assertRejected(.noKeywords("fall"), edit("fall") { $0.keywords.append("  ") })
    }

    func testGeneralNeedsNoKeywords() throws {
        XCTAssertNoThrow(try validate(edit("general") { $0.keywords = [] }).get())
    }

    func testTwoStepsAreRejected() throws {
        try assertRejected(.stepCount("fall"), edit("fall") { $0.steps = Array($0.steps.prefix(2)) })
    }

    func testSevenStepsAreRejected() throws {
        try assertRejected(.stepCount("head_injury"), edit("head_injury") { $0.steps.append("Stay with them.") })
    }

    func testAStepThatCountsIsRejected() throws {
        try assertRejected(.countingStep("unconscious"), edit("unconscious") { $0.steps[2] = "Count to 30 out loud." })
    }

    func testANonIFRCSourceIsRejected() throws {
        try assertRejected(.badSource("bleeding"), edit("bleeding") { $0.source = "A blog post" })
    }

    func testAPlaceholderSourceIsRejected() throws {
        try assertRejected(.badSource("bleeding"), edit("bleeding") { $0.source = "IFRC guidelines TODO page" })
    }

    func testAFirstStepWithout911IsRejected() throws {
        try assertRejected(.firstStep("fall"), edit("fall") { $0.steps[0] = "Make sure help is on the way." })
    }

    func testAnEmptyTitleIsRejected() throws {
        try assertRejected(.noTitle("fall"), edit("fall") { $0.title = " " })
    }

    func testAnUnknownScriptIsDroppedAndTheRestKept() throws {
        let database = try validate { database in
            var burn = database.scripts[0]
            burn.id = "burn"
            database.scripts.insert(burn, at: 0)
        }.get()

        XCTAssertFalse(database.scripts.contains { $0.id == "burn" })
        XCTAssertEqual(database.scripts.map(\.id), try DatabaseFixtures.bundled().scripts.map(\.id))
    }

    /// Order is classifier priority, so validation must not reorder.
    func testScriptAndKeywordOrderIsKept() throws {
        let database = try FirstAidDatabaseValidator.validate(DatabaseFixtures.bundledData()).get()
        XCTAssertEqual(database.keywords.entries.map(\.script), ["head_injury", "unconscious", "bleeding", "fall"])
        XCTAssertEqual(database.keywords.entries[0].keywords, ["tumama ang ulo", "nauntog", "nabagok", "nabagok ang ulo"])
    }
}
