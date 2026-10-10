import XCTest
@testable import Saklolo

final class ScriptLoaderTests: XCTestCase {
    /// The tests are hosted by the app, so `Bundle.main` is the shipped bundle.
    func testBundledScriptsLoadFromTheBuiltApp() throws {
        let scripts = try ScriptLoader().loadBundledScripts()
        let ids = Set(scripts.map(\.id))
        XCTAssertEqual(ids, ["general", "bleeding", "fall", "head_injury", "unconscious"])
    }

    /// The content rules (3 to 6 steps, IFRC source, no counting, help and
    /// 911 first) live in the validator, so a downloaded update meets them
    /// too. The shipped file must pass the same check.
    func testTheBundledDatabasePassesTheValidator() throws {
        let result = FirstAidDatabaseValidator.validate(try DatabaseFixtures.bundledData())
        XCTAssertNoThrow(try result.get(), "\(result)")
    }

    func testLoadedScriptsCarryTheFileContent() throws {
        let file = try DatabaseFixtures.bundled()
        let scripts = try ScriptLoader().loadBundledScripts()

        XCTAssertEqual(scripts.map(\.id), file.scripts.map(\.id))
        XCTAssertEqual(scripts.map(\.steps), file.scripts.map(\.steps))
        XCTAssertEqual(scripts.map(\.source), file.scripts.map(\.source))
    }
}
