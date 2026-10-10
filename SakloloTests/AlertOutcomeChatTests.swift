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

    func testNoFixAtAllIsOneChipSayingWhatTheTextSaid() {
        XCTAssertEqual(outcome(.awaitingConfirmation, names: [], location: nil).locationChipText, "Location unavailable")
    }

    func testALastKnownFixIsOneChipWithItsTime() {
        let taken = Date(timeIntervalSince1970: 1_800_000_000)
        let lastKnown = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: true, takenAt: taken)
        let time = taken.formatted(date: .omitted, time: .shortened)

        XCTAssertEqual(outcome(.awaitingConfirmation, names: [], location: lastKnown).locationChipText, "Last known location (\(time))")
    }

    func testALiveFixHasNoLocationChip() {
        XCTAssertNil(outcome(.awaitingConfirmation, names: [], location: liveFix).locationChipText)
    }

    // MARK: - Delivered banner

    private func outcome(_ delivery: AlertOutcome.Delivery, names: [String], location: AlertFix?, calledIndex: Int?) -> AlertOutcome {
        var result = outcome(delivery, names: names, location: location)
        result.records = names.indices.map {
            AlertOutcome.Record(contactID: UUID(), smsSentAt: nil, called: $0 == calledIndex)
        }
        return result
    }

    func testAConfirmedAlertReplacesTheSendingCardWithOneBannerInPlace() {
        let sent = outcome(.awaitingConfirmation, names: ["Kuya Ben", "Tita Lina"], location: liveFix)
        let before: [ChatMessage] = [.saklolo("What happened?"), .user("Papa fell")] + sent.chatMessages + [.saklolo("I'll guide you.")]
        let tapped = Date(timeIntervalSince1970: 1_800_000_000)
        var sentAtTap = sent
        sentAtTap.timestamp = tapped

        let after = sentAtTap.confirming(before, at: tapped.addingTimeInterval(95))

        XCTAssertEqual(after.count, before.count)
        XCTAssertEqual(after[2].kind, .alert(told: "I've told Kuya Ben and Tita Lina", sentText: "SAKLOLO: Papa fell. 7:42 PM.", chips: [.location, .textSent], at: tapped))
        XCTAssertEqual(after.filter { if case .alert = $0.kind { true } else { false } }.count, 1)
        XCTAssertEqual(after.last, before.last)
    }

    func testAConfirmedRetryOrComposerSendAlsoBecomesTheBannerAndKeepsTheLocationCard() {
        let lastKnown = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: true)
        for delivery in [AlertOutcome.Delivery.queued, .sendFailed] {
            let sent = outcome(delivery, names: ["Kuya Ben"], location: lastKnown)
            let after = sent.confirming(sent.chatMessages, at: .now)

            guard case .alert = after[0].kind else { return XCTFail("\(delivery): no banner") }
            XCTAssertEqual(after[1].kind, .fallback(.noLocation))
        }
    }

    func testConfirmingTwiceKeepsOneBanner() {
        let sent = outcome(.awaitingConfirmation, names: ["Kuya Ben"], location: liveFix)
        let once = sent.confirming(sent.chatMessages, at: .now)

        XCTAssertEqual(sent.confirming(once, at: .distantFuture), once)
    }

    func testTheBannerShowsTheAlertsOwnTimeNotTheConfirmationTime() {
        var sent = outcome(.awaitingConfirmation, names: ["Kuya Ben"], location: liveFix)
        let tapped = Date(timeIntervalSince1970: 1_800_000_000)
        sent.timestamp = tapped

        let banner = sent.confirming(sent.chatMessages, at: tapped.addingTimeInterval(3_600))[0]

        guard case .alert(_, _, _, let at) = banner.kind else { return XCTFail("no banner") }
        XCTAssertEqual(at, tapped)
    }

    func testTheChipsNameEveryRecordedPartInTheMockupsOrder() {
        let chips = outcome(.awaitingConfirmation, names: ["Kuya Ben", "Tita Lina", "Ruel"], location: liveFix, calledIndex: 0).deliveryChips

        XCTAssertEqual(chips.map(\.text), ["Location", "Text sent", "Calling Kuya Ben"])
    }

    func testTheChipsNeverSayLocationWithoutALiveFixOrCallingWithoutACall() {
        let lastKnown = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: true)

        XCTAssertEqual(outcome(.awaitingConfirmation, names: ["Kuya Ben"], location: lastKnown, calledIndex: nil).deliveryChips, [.textSent])
        XCTAssertEqual(outcome(.awaitingConfirmation, names: ["Kuya Ben"], location: nil, calledIndex: 0).deliveryChips, [.textSent, .calling("Kuya Ben")])
        XCTAssertEqual(outcome(.awaitingConfirmation, names: [], location: liveFix, calledIndex: nil).deliveryChips, [.location, .textSent])
    }

    // MARK: - Fixed replies

    func testCouldNotUnderstandSaysAGeneralAlertAndGeneralHelpFollow() {
        XCTAssertEqual(ChatReplies.couldNotUnderstand, "I couldn't understand that. I'm sending a general alert and starting general help.")
    }

    func testAloneWithTheDockShownChecksInWithTheCountdownLength() {
        let alone = SituationClassification(mode: .alone, scriptID: "fall", summary: "Fell", urgency: "high")

        XCTAssertEqual(ChatReplies.replies(for: alone, dockShown: true), [
            "Stay still. I'm here.",
            "Are you okay? Slide if you're okay. If not, I'll tell your contacts in 10 seconds, or tap I need help to do it now.",
        ])
    }

    func testAloneAfterTheAlertAlreadyWentNeverOffersTheSlide() {
        let alone = SituationClassification(mode: .alone, scriptID: "fall", summary: "Fell", urgency: "high")
        let replies = ChatReplies.replies(for: alone, dockShown: false)

        XCTAssertEqual(replies.first, "Stay still. I'm here.")
        XCTAssertFalse(replies.joined().contains("Slide"))
    }

    func testGuideRepliesAreUnchanged() {
        let guide = SituationClassification(mode: .guide, scriptID: "bleeding", summary: "Bleeding", urgency: "high")

        XCTAssertEqual(ChatReplies.replies(for: guide, dockShown: false), [
            "Got it. Someone with you is bleeding.",
            "I'll guide you, one step at a time.",
        ])
    }

    func testNoFixAtAllAlsoShowsTheLocationCard() {
        let kinds = outcome(.queued, names: ["Kuya Ben"], location: nil).chatMessages.map(\.kind)

        XCTAssertEqual(kinds.filter { $0 == .fallback(.noLocation) }.count, 1)
        XCTAssertEqual(kinds.first, .fallback(.noSignal))
        XCTAssertTrue(isText(kinds.last!))
    }
}
