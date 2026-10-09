import Foundation
import XCTest
@testable import Saklolo

@MainActor
final class AlertQueueTests: XCTestCase {
    private let sentAt = Date(timeIntervalSince1970: 1_800_000_300)
    private var sender: RecordingSender!
    private var signal: SignalSwitch!
    private var queue: AlertQueue!

    override func setUp() async throws {
        sender = RecordingSender()
        signal = SignalSwitch(on: false)
        queue = AlertQueue(sender: sender, signal: signal, now: { [sentAt] in sentAt })
    }

    private func outcome(_ delivery: AlertOutcome.Delivery, text: String = "SAKLOLO: Papa fell. 7:42 PM.") -> AlertOutcome {
        AlertOutcome(
            delivery: delivery,
            isGeneral: false,
            message: text,
            recipientNames: ["Kuya Ben"],
            location: nil,
            records: [AlertOutcome.Record(contactID: UUID(), smsSentAt: nil, called: false)]
        )
    }

    func testAHeldTextWaitsWhileThereIsNoSignal() {
        queue.record(outcome(.queued))

        queue.retry()

        XCTAssertTrue(sender.texts.isEmpty)
        XCTAssertEqual(queue.latest?.status, .waiting)
    }

    func testAHeldTextGoesOnceSignalReturnsAndOnlyOnce() {
        queue.record(outcome(.queued, text: "SAKLOLO: held"))

        signal.hasSignal = true
        queue.retry()
        queue.retry()

        XCTAssertEqual(sender.texts, ["SAKLOLO: held"])
        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
    }

    func testTheUnsentRowsAreStampedWhenTheRetrySucceeds() {
        let held = outcome(.queued)
        queue.record(held)
        var stamped: [Date] = []
        queue.whenSent(held.id) { stamped.append($0) }

        signal.hasSignal = true
        queue.retry()

        XCTAssertEqual(stamped, [sentAt])
    }

    func testARetryTheShortcutCannotSendMovesToTheComposer() {
        queue.record(outcome(.queued))
        sender.textFails = true

        signal.hasSignal = true
        queue.retry()

        XCTAssertEqual(queue.latest?.status, .needsComposer)
    }

    func testAFailedSendIsNotRetriedByItselfButTheComposerCompletesIt() {
        let failed = outcome(.sendFailed)
        queue.record(failed)
        var stamped: [Date] = []
        queue.whenSent(failed.id) { stamped.append($0) }

        signal.hasSignal = true
        queue.retry()
        XCTAssertTrue(sender.texts.isEmpty)

        queue.composerSent(failed.id)
        queue.composerSent(failed.id)

        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
        XCTAssertEqual(stamped, [sentAt])
    }

    func testWaitingOnAnAlertAlreadySentRunsAtOnce() {
        let early = Date(timeIntervalSince1970: 1_800_000_004)
        var sent = outcome(.sent)
        sent.records = [AlertOutcome.Record(contactID: UUID(), smsSentAt: early, called: true)]
        queue.record(sent)
        var stamped: [Date] = []

        queue.whenSent(sent.id) { stamped.append($0) }

        XCTAssertEqual(stamped, [early])
    }

    func testTheLatestAlertIsTheOneTheCardsShow() {
        queue.record(outcome(.queued, text: "first"))
        queue.record(outcome(.sendFailed, text: "second"))

        XCTAssertEqual(queue.latest?.outcome.message, "second")
        XCTAssertTrue(queue.hasWaiting)
    }

    func testSignalMeansAnyPathOrACellularRadio() {
        XCTAssertTrue(NetworkMonitor.hasSignal(pathSatisfied: true, cellularAvailable: false))
        XCTAssertTrue(NetworkMonitor.hasSignal(pathSatisfied: false, cellularAvailable: true))
        XCTAssertFalse(NetworkMonitor.hasSignal(pathSatisfied: false, cellularAvailable: false))
    }
}
