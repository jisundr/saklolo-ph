import Foundation
import XCTest
@testable import Saklolo

final class KeywordDatabaseTests: XCTestCase {
    /// Each script JSON carries its own keywords; the classifier reads
    /// `keywords.json`. They must not drift apart.
    func testEveryScriptKeywordResolvesToItsOwnScript() throws {
        let db = KeywordDatabase.bundled()
        for script in try ScriptLoader().loadBundledScripts() {
            for keyword in script.keywords {
                XCTAssertEqual(db.match(keyword), script.id, "\"\(keyword)\" in \(script.id).json")
            }
        }
    }

    /// `builtIn` is the last resort and must say what the bundled file says.
    func testTheBuiltInListMatchesTheBundledFile() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "keywords", withExtension: "json"))
        let bundled = try XCTUnwrap(KeywordDatabase.load(from: url))

        XCTAssertEqual(bundled.entries.map(\.script), KeywordDatabase.builtIn.entries.map(\.script))
        XCTAssertEqual(bundled.entries.map(\.keywords), KeywordDatabase.builtIn.entries.map(\.keywords))
    }

    func testFaintingIsTreatedAsUnconscious() {
        let db = KeywordDatabase.bundled()

        XCTAssertEqual(db.match("hinimatay si Lola"), "unconscious")
        XCTAssertEqual(db.match("Nahimatay siya sa kusina"), "unconscious")
    }
}
