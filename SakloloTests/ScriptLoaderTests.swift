import XCTest
@testable import Saklolo

final class ScriptLoaderTests: XCTestCase {
    /// The tests are hosted by the app, so `Bundle.main` is the shipped bundle.
    func testBundledScriptsLoadFromTheBuiltApp() throws {
        let scripts = try ScriptLoader().loadBundledScripts()
        let ids = Set(scripts.map(\.id))
        XCTAssertEqual(ids, ["general", "bleeding", "fall", "head_injury", "unconscious"])
    }

    func testEveryScriptHasStepsAndASource() throws {
        for script in try ScriptLoader().loadBundledScripts() {
            XCTAssertFalse(script.steps.isEmpty, "\(script.id) has no steps")
            XCTAssertFalse(script.source.isEmpty, "\(script.id) has no source")
        }
    }
}
