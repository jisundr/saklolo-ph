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

    func testAnAlertHandedToTheShortcutIsOneSendingCardAndNeverClaimsContactsWereTold() {
        let messages = outcome(.awaitingConfirmation, names: ["Kuya Ben", "Tita Lina"], location: liveFix).chatMessages

        XCTAssertEqual(messages.map(\.kind), [.fallback(.sending)])
        XCTAssertEqual(messages[0].role, .saklolo)
    }

    func testTheSendingLineNamesTheContactsWithoutSayingTheyWereTold() {
        let line = outcome(.awaitingConfirmation, names: ["Kuya Ben", "Tita Lina"]).sendingLine

        XCTAssertTrue(line.hasPrefix("Sending the alert to Kuya Ben and Tita Lina"))
        XCTAssertFalse(line.contains("told"))
    }

    func testTheToldLineWithNoSavedContactsNamesNoOne() {
        let line = outcome(.awaitingConfirmation, names: []).toldLine

        XCTAssertFalse(line.contains("told"))
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
        let kinds = outcome(.awaitingConfirmation, names: ["Kuya Ben"], location: lastKnown).chatMessages.map(\.kind)

        XCTAssertEqual(kinds, [.fallback(.sending), .fallback(.noLocation)])
    }

    func testNoFixAtAllAlsoShowsTheLocationCard() {
        let kinds = outcome(.queued, names: ["Kuya Ben"], location: nil).chatMessages.map(\.kind)

        XCTAssertEqual(kinds.filter { $0 == .fallback(.noLocation) }.count, 1)
        XCTAssertEqual(kinds.first, .fallback(.noSignal))
        XCTAssertTrue(isText(kinds.last!))
    }
}
