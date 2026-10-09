import Foundation
import XCTest
@testable import Saklolo

final class AlertOutcomeChatTests: XCTestCase {
    private func outcome(_ delivery: AlertOutcome.Delivery, names: [String]) -> AlertOutcome {
        AlertOutcome(
            delivery: delivery,
            isGeneral: false,
            message: "SAKLOLO: Papa fell. 7:42 PM.",
            recipientNames: names,
            location: nil,
            records: []
        )
    }

    func testASentAlertIsOneEntryNamingTheContactsWithTheText() {
        let messages = outcome(.sent, names: ["Kuya Ben", "Tita Lina"]).chatMessages

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

        XCTAssertTrue(kinds.contains(.fallback(.sendFailed)))
        XCTAssertFalse(kinds.contains { if case .alert = $0 { true } else { false } })
    }
}
