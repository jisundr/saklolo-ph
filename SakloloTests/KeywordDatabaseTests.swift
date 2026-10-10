import Foundation
import XCTest
@testable import Saklolo

final class KeywordDatabaseTests: XCTestCase {
    /// Keywords live only in each script of `database.json`; every one of
    /// them must lead the classifier to its own script, not an earlier one.
    func testEveryScriptKeywordResolvesToItsOwnScript() throws {
        let db = KeywordDatabase.bundled()
        for script in try ScriptLoader().loadBundledScripts() where script.id != "general" {
            for keyword in script.keywords {
                XCTAssertEqual(db.match(keyword), script.id, "\"\(keyword)\" in \(script.id)")
            }
        }
    }

    /// `builtIn` is the last resort and must say what the bundled file says.
    func testTheBuiltInListMatchesTheBundledFile() throws {
        let bundled = try XCTUnwrap(FirstAidDatabase.bundled()).keywords

        XCTAssertEqual(bundled.entries.map(\.script), KeywordDatabase.builtIn.entries.map(\.script))
        XCTAssertEqual(bundled.entries.map(\.keywords), KeywordDatabase.builtIn.entries.map(\.keywords))
    }

    func testFaintingIsTreatedAsUnconscious() {
        let db = KeywordDatabase.bundled()

        XCTAssertEqual(db.match("hinimatay si Lola"), "unconscious")
        XCTAssertEqual(db.match("Nahimatay siya sa kusina"), "unconscious")
    }
}
