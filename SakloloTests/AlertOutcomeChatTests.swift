import Foundation
import XCTest
@testable import Saklolo

final class AlertOutcomeChatTests: XCTestCase {
    private let liveFix = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: false)

    private func outcome(_ delivery: AlertOutcome.Delivery, names: [String], location: AlertFix? = nil) -> AlertOutcome {
        AlertOutcome(
            delivery: delivery,
            isGeneral: false,
            message: "SAKLOLO: Papa fell. 7:42 PM.",
            recipientNames: names,
            location: location,
            records: []
        )
    }

    private func isText(_ kind: ChatMessage.Kind) -> Bool {
        if case .text = kind { true } else { false }
    }

    func testASentAlertIsOneEntryNamingTheContactsWithTheText() {
        let messages = outcome(.sent, names: ["Kuya Ben", "Tita Lina"], location: liveFix).chatMessages

        XCTAssertEqual(messages.count, 1)
        guard case .alert(let text) = messages[0].kind else { return XCTFail("expected an alert entry") }
        XCTAssertTrue(text.hasPrefix("I've told Kuya Ben and Tita Lina"))
        XCTAssertTrue(text.contains("SAKLOLO: Papa fell. 7:42 PM."))
        XCTAssertEqual(messages[0].role, .saklolo)
    }

    func testASentAlertWithNoSavedContactsNamesNoOne() {
        let messages = outcome(.sent, names: []).chatMessages

        guard case .alert(let text) = messages.first?.kind else { return XCTFail("expected an alert entry") }
        XCTAssertFalse(text.contains("told"))
        XCTAssertTrue(text.contains("SAKLOLO: Papa fell."))
    }

    func testAFailedSendShowsTheSendFailedCardAndNoAlertEntry() {
        let kinds = outcome(.sendFailed, names: ["Kuya Ben"]).chatMessages.map(\.kind)

        XCTAssertEqual(kinds.first, .fallback(.sendFailed))
        XCTAssertFalse(kinds.contains { if case .alert = $0 { true } else { false } })
    }

    func testAFailedSendHasNoSeparateFailureBubbleOnlyTheCardThenKeepGuiding() {
        let kinds = outcome(.sendFailed, names: ["Kuya Ben"], location: liveFix).chatMessages.map(\.kind)

        XCTAssertEqual(kinds, [.fallback(.sendFailed), .text(AlertOutcome.keepGuiding)])
    }

    func testNoSignalShowsTheQueuedCardAndThatFirstAidStillWorks() {
        let kinds = outcome(.queued, names: ["Kuya Ben"], location: liveFix).chatMessages.map(\.kind)

        XCTAssertEqual(kinds, [.fallback(.noSignal), .text(AlertOutcome.firstAidStillWorks)])
    }

    func testALastKnownLocationAddsTheLocationCardAfterTheAlert() {
        let lastKnown = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: true)
        let kinds = outcome(.sent, names: ["Kuya Ben"], location: lastKnown).chatMessages.map(\.kind)

        XCTAssertEqual(kinds.count, 2)
        guard case .alert = kinds[0] else { return XCTFail("expected the alert entry first") }
        XCTAssertEqual(kinds[1], .fallback(.noLocation))
    }

    func testNoFixAtAllAlsoShowsTheLocationCard() {
        let kinds = outcome(.queued, names: ["Kuya Ben"], location: nil).chatMessages.map(\.kind)

        XCTAssertEqual(kinds.filter { $0 == .fallback(.noLocation) }.count, 1)
        XCTAssertEqual(kinds.first, .fallback(.noSignal))
        XCTAssertTrue(isText(kinds.last!))
    }
}
