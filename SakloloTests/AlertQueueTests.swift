import Foundation
import SwiftData
import XCTest
@testable import Saklolo

@MainActor
final class AlertQueueTests: XCTestCase {
    private let sentAt = Date(timeIntervalSince1970: 1_800_000_300)
    private var sender: RecordingSender!
    private var signal: SignalSwitch!
    private var queue: AlertQueue!
    private var clock: TestClock!

    override func setUp() async throws {
        sender = RecordingSender()
        signal = SignalSwitch(on: false)
        clock = TestClock()
        queue = AlertQueue(sender: sender, signal: signal, now: { [sentAt] in sentAt }, sleep: { [clock] in
            try await clock!.sleep(for: $0)
        })
    }

    override func tearDown() async throws {
        clock.advance(by: .seconds(60))
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

    func testAHeldTextIsHandedOverOnceSignalReturnsAndOnlyOnce() {
        let held = outcome(.queued, text: "SAKLOLO: held")
        queue.record(held)

        signal.hasSignal = true
        queue.retry()
        queue.retry()

        XCTAssertEqual(sender.texts, ["SAKLOLO: held"])
        XCTAssertEqual(sender.ids, [held.id])
        XCTAssertEqual(queue.latest?.status, .confirming, "not sent until the Shortcut confirms")
    }

    func testTheUnsentRowsAreStampedWhenTheRetryIsConfirmed() {
        let held = outcome(.queued)
        queue.record(held)
        var stamped: [Date] = []
        queue.whenSent(held.id) { stamped.append($0) }

        signal.hasSignal = true
        queue.retry()
        XCTAssertEqual(stamped, [])
        queue.resolve(held.id, .sent)

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

    func testWaitingOnAnAlertAlreadyConfirmedRunsAtOnce() {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)
        queue.resolve(handed.id, .sent)
        var stamped: [Date] = []

        queue.whenSent(handed.id) { stamped.append($0) }

        XCTAssertEqual(stamped, [sentAt])
    }

    // MARK: - Confirmation from the Shortcut

    func testAnAlertHandedToTheShortcutIsNotSentUntilConfirmed() {
        queue.record(outcome(.awaitingConfirmation))

        XCTAssertEqual(queue.latest?.status, .confirming)
    }

    func testXSuccessMarksTheAlertSent() {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)

        XCTAssertTrue(queue.handle(AlertCallback.url(.sent, id: handed.id)))

        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
    }

    func testXErrorAndXCancelMoveTheAlertToTheComposerWithoutResending() {
        for result in [AlertCallback.Result.failed, .cancelled] {
            let handed = outcome(.awaitingConfirmation)
            queue.record(handed)
            signal.hasSignal = true

            queue.handle(AlertCallback.url(result, id: handed.id))
            queue.retry()

            XCTAssertEqual(queue.latest?.status, .needsComposer, "\(result)")
        }
        XCTAssertTrue(sender.texts.isEmpty)
    }

    func testACallbackThatArrivesBeforeTheAlertIsRecordedStillCounts() {
        let handed = outcome(.awaitingConfirmation)

        queue.resolve(handed.id, .sent)
        queue.record(handed)

        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
    }

    func testAnotherURLIsNotACallback() {
        queue.record(outcome(.awaitingConfirmation))

        XCTAssertFalse(queue.handle(URL(string: "https://example.com/alert")!))
        XCTAssertEqual(queue.latest?.status, .confirming)
    }

    /// Waits for the confirmation timer to start sleeping on the test clock.
    private func waitForTimer() async {
        for _ in 0..<1_000 where clock.sleeperCount == 0 { await Task.yield() }
        XCTAssertEqual(clock.sleeperCount, 1)
    }

    private func waitForStatus(_ status: AlertQueue.Entry.Status) async {
        for _ in 0..<1_000 where queue.latest?.status != status { await Task.yield() }
    }

    func testNoCallbackSoonAfterComingBackFromShortcutsMovesToTheComposer() async {
        queue.record(outcome(.awaitingConfirmation))

        queue.appLeft()
        queue.appReturned()
        await waitForTimer()
        clock.advance(by: AlertPolicy.confirmationWait - .milliseconds(1))
        await Task.yield()
        XCTAssertEqual(queue.latest?.status, .confirming)

        clock.advance(by: .milliseconds(1))
        await waitForStatus(.needsComposer)

        XCTAssertEqual(queue.latest?.status, .needsComposer)
        XCTAssertTrue(sender.texts.isEmpty, "never resent by itself")
    }

    func testTheWaitOnlyStartsOnceTheAppHasLeftForShortcutsAndComeBack() async {
        queue.record(outcome(.awaitingConfirmation))

        queue.appReturned()
        await Task.yield()

        XCTAssertEqual(clock.sleeperCount, 0)
        XCTAssertEqual(queue.latest?.status, .confirming)
    }

    func testAConfirmationWithinTheWaitIsKept() async {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)
        queue.appLeft()
        queue.appReturned()
        await waitForTimer()

        queue.resolve(handed.id, .sent)
        clock.advance(by: AlertPolicy.confirmationWait)
        await Task.yield()

        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
    }

    func testALateXSuccessAfterTheComposerCardStillMarksItSent() {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)
        queue.resolve(handed.id, .failed)

        queue.resolve(handed.id, .sent)

        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
    }

    // MARK: - Stored rows

    private func storedIncident() throws -> (ModelContext, Incident) {
        let container = try ModelContainer(
            for: Incident.self, Alert.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let incident = Incident(trigger: "button", mode: .guide)
        context.insert(incident)
        return (context, incident)
    }

    func testARetryStampsTheStoredRowsOfAQueuedAlert() throws {
        let (context, incident) = try storedIncident()
        let held = outcome(.queued)
        queue.record(held)
        let rows = held.alerts(for: incident, queue: queue)
        rows.forEach(context.insert)
        try context.save()

        signal.hasSignal = true
        queue.retry()
        queue.resolve(held.id, .sent)

        XCTAssertEqual(rows.map(\.smsSentAt), [sentAt])
    }

    func testARetryAfterTheIncidentIsDeletedLeavesItsRowsAlone() throws {
        let (context, incident) = try storedIncident()
        let held = outcome(.queued)
        queue.record(held)
        let rows = held.alerts(for: incident, queue: queue)
        rows.forEach(context.insert)
        try context.save()

        context.delete(incident)
        try context.save()
        signal.hasSignal = true
        queue.retry()
        queue.resolve(held.id, .sent)

        XCTAssertEqual(sender.texts.count, 1, "the text itself still goes out")
        XCTAssertFalse(rows[0].isStored)
        XCTAssertNil(rows[0].smsSentAt, "nothing is written to a deleted row")
        XCTAssertEqual(queue.latest?.status, .sent(at: sentAt))
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

    // MARK: - What the fallback cards show

    private func face(_ kind: FallbackKind) -> FallbackCardView.Face {
        FallbackCardView.face(for: kind, entry: queue.latest)
    }

    func testTheSendingCardSaysDeliveredOnlyOnceTheShortcutConfirms() {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)
        XCTAssertEqual(face(.sending), .sending)

        queue.resolve(handed.id, .sent)

        XCTAssertEqual(face(.sending), .delivered(at: sentAt))
    }

    func testTheSendingCardOffersTheComposerWhenTheShortcutFails() {
        let handed = outcome(.awaitingConfirmation)
        queue.record(handed)

        queue.resolve(handed.id, .failed)

        XCTAssertEqual(face(.sending), .couldNotSend)
    }

    func testTheCouldNotSendCardTurnsDeliveredAfterTheComposerSends() {
        let failed = outcome(.sendFailed)
        queue.record(failed)
        XCTAssertEqual(face(.sendFailed), .couldNotSend)

        queue.composerSent(failed.id)

        XCTAssertEqual(face(.sendFailed), .delivered(at: sentAt))
        XCTAssertEqual(face(.composer), .hidden, "no second Send message once it went out")
    }

    func testTheNoSignalCardTurnsDeliveredOnceARetryIsConfirmed() {
        let held = outcome(.queued)
        queue.record(held)
        XCTAssertEqual(face(.noSignal), .noSignal)

        signal.hasSignal = true
        queue.retry()
        XCTAssertEqual(face(.noSignal), .noSignal, "handed over is not delivered")
        queue.resolve(held.id, .sent)

        XCTAssertEqual(face(.noSignal), .delivered(at: sentAt))
    }

    func testTheNoSignalCardOffersTheComposerWhenARetryCannotSend() {
        queue.record(outcome(.queued))
        sender.textFails = true

        signal.hasSignal = true
        queue.retry()

        XCTAssertEqual(face(.noSignal), .couldNotSend)
    }

    func testNoFixAtAllIsAFailurePillAndALastKnownFixIsAPlainOne() {
        queue.record(outcome(.awaitingConfirmation))
        XCTAssertEqual(face(.noLocation), .location(.init(text: "Location unavailable", isFailure: true)))

        var lastKnown = outcome(.awaitingConfirmation)
        lastKnown.location = AlertFix(lat: 14.65, lng: 121.05, isLastKnown: true)
        queue.record(lastKnown)
        XCTAssertEqual(face(.noLocation), .location(.init(text: "Last known location", isFailure: false)))

        var live = outcome(.awaitingConfirmation)
        live.location = AlertFix(lat: 14.65, lng: 121.05, isLastKnown: false)
        queue.record(live)
        XCTAssertEqual(face(.noLocation), .hidden)
    }

    func testNoCardWithoutAnAlert() {
        XCTAssertEqual(face(.sending), .sending, "a placeholder until the alert is recorded")
        XCTAssertEqual(face(.composer), .hidden)
        XCTAssertEqual(face(.noLocation), .hidden)
    }
}
