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

    /// FR-S4: the guide opens by making sure help is being called.
    func testEveryScriptStartsByMakingSureHelpIsOnTheWay() throws {
        for script in try ScriptLoader().loadBundledScripts() {
            let first = try XCTUnwrap(script.steps.first, "\(script.id) has no steps")
            XCTAssertTrue(first.localizedCaseInsensitiveContains("help"), "\(script.id) first step: \(first)")
            XCTAssertTrue(first.contains("911"), "\(script.id) first step: \(first)")
        }
    }

    func testEverySourceCitesTheIFRCGuidelinesWithoutPlaceholders() throws {
        for script in try ScriptLoader().loadBundledScripts() {
            XCTAssertTrue(script.source.contains("IFRC"), "\(script.id) source: \(script.source)")
            XCTAssertFalse(script.source.localizedCaseInsensitiveContains("TODO"), "\(script.id) source: \(script.source)")
        }
    }

    /// The app does not count CPR compressions, so no step may promise it.
    func testNoStepPromisesCounting() throws {
        for script in try ScriptLoader().loadBundledScripts() {
            for step in script.steps {
                XCTAssertFalse(step.localizedCaseInsensitiveContains("count"), "\(script.id) step: \(step)")
            }
        }
    }

    func testEveryScriptHasThreeToSixSteps() throws {
        for script in try ScriptLoader().loadBundledScripts() {
            XCTAssertTrue((3...6).contains(script.steps.count), "\(script.id) has \(script.steps.count) steps")
        }
    }
}
