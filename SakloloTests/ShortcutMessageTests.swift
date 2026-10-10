import Foundation
import XCTest
@testable import Saklolo

final class ShortcutMessageTests: XCTestCase {
    private let service = ShortcutSMSService()
    private let at = Date(timeIntervalSince1970: 1_800_000_000)

    func testALiveFixIsSentAsLocation() {
        let text = service.buildMessage(summary: "Papa fell", timestamp: at, lat: 14.6507, lng: 121.0494)

        XCTAssertTrue(text.hasPrefix("SAKLOLO: Papa fell. "))
        XCTAssertTrue(text.hasSuffix(" Location: maps.apple.com/?ll=14.6507,121.0494"))
    }

    func testALastKnownFixIsLabelledInTheText() {
        let text = service.buildMessage(
            summary: "Papa fell", timestamp: at, lat: 14.6507, lng: 121.0494,
            locationNote: "Last known location (7:31 PM)"
        )

        XCTAssertTrue(text.hasSuffix(" Last known location (7:31 PM): maps.apple.com/?ll=14.6507,121.0494"))
        XCTAssertFalse(text.contains(" Location:"))
    }

    func testNoFixSendsTheNoteOnItsOwn() {
        let text = service.buildMessage(summary: "Papa fell", timestamp: at, lat: nil, lng: nil, locationNote: "Location unavailable")

        XCTAssertTrue(text.hasSuffix(" Location unavailable."))
        XCTAssertFalse(text.contains("maps.apple.com"))
    }

    func testNoFixAndNoNoteLeavesLocationOut() {
        let text = service.buildMessage(summary: "Papa fell", timestamp: at, lat: nil, lng: nil)

        XCTAssertFalse(text.contains("ocation"))
    }

    // MARK: - Who needs help

    private var time: String { at.formatted(date: .omitted, time: .shortened) }

    func testTheTextNamesThePersonBeforeWhatHappened() {
        let text = service.buildMessage(summary: "Papa fell", name: "Jayson", timestamp: at, lat: nil, lng: nil)

        XCTAssertEqual(text, "SAKLOLO: Jayson needs help. Papa fell. \(time).")
    }

    func testTheGeneralTextNamesThePerson() {
        let text = service.buildMessage(summary: nil, name: "Jayson", timestamp: at, lat: nil, lng: nil, locationNote: "Location unavailable")

        XCTAssertEqual(text, "SAKLOLO: Jayson needs help. Could not say what happened. \(time). Location unavailable.")
    }

    func testWithNoNameStoredTheGeneralTextKeepsItsWording() {
        for name in [nil, "", "   "] as [String?] {
            let text = service.buildMessage(summary: nil, name: name, timestamp: at, lat: nil, lng: nil)

            XCTAssertEqual(text, "SAKLOLO: I need help. I could not say what happened. \(time).", "\(String(describing: name))")
        }
    }

    func testWithNoNameStoredTheSummaryLeadsAsBefore() {
        let text = service.buildMessage(summary: "Papa fell", name: nil, timestamp: at, lat: nil, lng: nil)

        XCTAssertEqual(text, "SAKLOLO: Papa fell. \(time).")
    }

    func testABlankSummaryIsTheGeneralTextAndAFullStopIsNotDoubled() {
        XCTAssertEqual(
            service.buildMessage(summary: "  ", name: " Jayson ", timestamp: at, lat: nil, lng: nil),
            "SAKLOLO: Jayson needs help. Could not say what happened. \(time)."
        )
        XCTAssertEqual(
            service.buildMessage(summary: "Papa fell.", name: "Jayson", timestamp: at, lat: nil, lng: nil),
            "SAKLOLO: Jayson needs help. Papa fell. \(time)."
        )
    }
}
