import Foundation
import XCTest
@testable import Saklolo

final class AlertCallbackTests: XCTestCase {
    private let id = UUID(uuidString: "6F1B2C3D-0000-4000-8000-000000000001")!

    func testEachResultComesBackForItsAlert() {
        for result in [AlertCallback.Result.sent, .failed, .cancelled] {
            let parsed = AlertCallback.parse(AlertCallback.url(result, id: id))
            XCTAssertEqual(parsed?.id, id)
            XCTAssertEqual(parsed?.result, result)
        }
    }

    func testTheQueryShortcutsAppendsIsIgnored() {
        let url = URL(string: "saklolo://alert/\(id.uuidString)/failed?errorMessage=Could%20not%20find%20the%20shortcut")!

        XCTAssertEqual(AlertCallback.parse(url)?.result, .failed)
    }

    func testOtherURLsAreNotCallbacks() {
        XCTAssertNil(AlertCallback.parse(URL(string: "saklolo://alert/not-a-uuid/sent")!))
        XCTAssertNil(AlertCallback.parse(URL(string: "saklolo://alert/\(id.uuidString)/maybe")!))
        XCTAssertNil(AlertCallback.parse(URL(string: "https://alert/\(id.uuidString)/sent")!))
    }

    func testTheShortcutURLCarriesTheExactTextAndTheThreeCallbacks() throws {
        let message = "SAKLOLO: Papa & Tita fell, 1+1=2? Ñ. 7:42 PM. Location: maps.apple.com/?ll=14.6,121.0"
        let url = try XCTUnwrap(AlertCallback.shortcutURL(message: message, recipients: ["+639171234567"], id: id))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(parts.scheme, "shortcuts")
        XCTAssertEqual(parts.host, "x-callback-url")
        XCTAssertEqual(parts.path, "/run-shortcut")
        XCTAssertEqual(query["name"], "Saklolo")
        XCTAssertEqual(query["input"], "text")
        let input = try XCTUnwrap(query["text"]?.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: input) as? [String: Any])
        XCTAssertEqual(payload["text"] as? String, message)
        XCTAssertEqual(payload["to"] as? [String], ["+639171234567"])
        XCTAssertEqual(query["x-success"].flatMap(URL.init(string:)).flatMap(AlertCallback.parse)?.result, .sent)
        XCTAssertEqual(query["x-error"].flatMap(URL.init(string:)).flatMap(AlertCallback.parse)?.result, .failed)
        XCTAssertEqual(query["x-cancel"].flatMap(URL.init(string:)).flatMap(AlertCallback.parse)?.result, .cancelled)
    }
}
