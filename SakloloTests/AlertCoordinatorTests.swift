import Foundation
import XCTest
@testable import Saklolo

@MainActor
final class AlertCoordinatorTests: XCTestCase {
    private let tap = Date(timeIntervalSince1970: 1_800_000_000)
    private let ben = AlertRecipient(contactID: UUID(), name: "Kuya Ben", phone: "+63 917 000 0001", priority: 0)
    private let lina = AlertRecipient(contactID: UUID(), name: "Tita Lina", phone: "+63 917 000 0002", priority: 1)

    private var sender: RecordingSender!
    private var locator: FakeLocator!
    private var clock: TestClock!
    private var coordinator: AlertCoordinator<TestClock>!

    override func setUp() async throws {
        sender = RecordingSender()
        locator = FakeLocator(fix: AlertFix(lat: 14.5995, lng: 120.9842, isLastKnown: false))
        clock = TestClock()
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock)
    }

    override func tearDown() async throws {
        coordinator.cancel()
        clock.advance(by: .seconds(60))
    }

    /// Sends and expects an outcome back.
    private func sent(_ classification: SituationClassification?) async throws -> AlertOutcome {
        let outcome = await coordinator.send(classification: classification)
        return try XCTUnwrap(outcome)
    }

    private func fall(summary: String = "Papa fell, his head is bleeding") -> SituationClassification {
        SituationClassification(mode: .guide, scriptID: "fall", summary: summary, urgency: "high")
    }

    // MARK: - Understanding before the deadline

    func testUnderstandingBeforeDeadlineSendsTheSpecificText() async throws {
        coordinator.begin(at: tap, recipients: [ben, lina]) { _ in XCTFail("deadline must not fire") }
        clock.advance(by: .seconds(6))

        let outcome = try await sent(fall())

        XCTAssertEqual(sender.texts.count, 1)
        XCTAssertTrue(outcome.awaitingConfirmation, "handed to the Shortcut, not yet known to be sent")
        XCTAssertFalse(outcome.isGeneral)
        XCTAssertTrue(sender.texts[0].contains("Papa fell, his head is bleeding"))
        XCTAssertTrue(sender.texts[0].contains("14.5995,120.9842"))
        XCTAssertEqual(outcome.message, sender.texts[0])
    }

    func testOnlyContactNumberOneIsCalledAndEveryContactGetsARecord() async throws {
        // Given out of order, to show priority decides who is called.
        coordinator.begin(at: tap, recipients: [lina, ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertEqual(sender.calls, [ben.phone])
        XCTAssertEqual(outcome.recipientNames, ["Kuya Ben", "Tita Lina"])
        XCTAssertEqual(outcome.records.count, 2)
        XCTAssertEqual(outcome.records.first { $0.contactID == ben.contactID }?.called, true)
        XCTAssertEqual(outcome.records.first { $0.contactID == lina.contactID }?.called, false)
        XCTAssertTrue(outcome.records.allSatisfy { $0.smsSentAt == nil }, "stamped only when the Shortcut confirms")
    }

    func testTheShortcutIsAskedToReportBackForThisAlert() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertEqual(sender.ids, [outcome.id])
    }

    func testTheShortcutFailingToOpenLaterMovesTheAlertToTheComposer() async throws {
        let queue = AlertQueue(sender: sender, signal: SignalSwitch(on: true))
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock, queue: queue)
        coordinator.begin(at: tap, recipients: [ben]) { _ in }
        _ = try await sent(fall())

        sender.reportNotOpened()

        XCTAssertEqual(queue.latest?.status, .needsComposer)
        XCTAssertEqual(sender.texts.count, 1, "never resent by itself")
    }

    // MARK: - Exactly one alert

    func testASecondSendSendsNothing() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        _ = await coordinator.send(classification: fall())
        let second = await coordinator.send(classification: fall(summary: "Someone else"))

        XCTAssertNil(second)
        XCTAssertEqual(sender.texts.count, 1)
        XCTAssertEqual(sender.calls.count, 1)
    }

    func testUnderstandingAfterTheDeadlineSendsNoSecondText() async throws {
        let deadline = expectation(description: "deadline send")
        coordinator.begin(at: tap, recipients: [ben]) { _ in deadline.fulfill() }

        clock.advance(by: AlertPolicy.deadline)
        await fulfillment(of: [deadline], timeout: 2)
        let late = await coordinator.send(classification: fall())

        XCTAssertNil(late)
        XCTAssertEqual(sender.texts.count, 1)
    }

    func testTwoSendsRacingProduceOneText() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }
        locator.suspends = true

        let coordinator = self.coordinator!
        let classification = fall()
        let first = Task { await coordinator.send(classification: classification) }
        let second = Task { await coordinator.send(classification: nil) }
        let results = [await first.value, await second.value]

        XCTAssertEqual(results.compactMap { $0 }.count, 1)
        XCTAssertEqual(sender.texts.count, 1)
    }

    // MARK: - Cancel and the end of the session

    func testCancelDuringTheLocationWaitStillSendsAndTheOutcomeCanBeAwaited() async throws {
        var fired = 0
        coordinator.onFire = { fired += 1 }
        coordinator.begin(at: tap, recipients: [ben]) { _ in }
        locator.parks = true

        let coordinator = self.coordinator!
        let classification = fall()
        let sending = Task { await coordinator.send(classification: classification) }
        while !locator.isParked { await Task.yield() }
        XCTAssertEqual(fired, 1, "the screen learns the alert is going out before the outcome")
        XCTAssertTrue(coordinator.hasFired)

        coordinator.cancel()
        let settled = Task { await coordinator.settledOutcome() }
        await Task.yield()
        locator.release()

        let settledOutcome = await settled.value
        let sentOutcome = await sending.value
        let outcome = try XCTUnwrap(settledOutcome)
        XCTAssertEqual(outcome, sentOutcome)
        XCTAssertEqual(sender.texts.count, 1)
        XCTAssertEqual(fired, 1)
    }

    func testNothingSettlesWhenCancelledBeforeTheAlertWent() async {
        var fired = false
        coordinator.onFire = { fired = true }
        coordinator.begin(at: tap, recipients: [ben]) { _ in XCTFail("cancelled") }

        coordinator.cancel()
        clock.advance(by: AlertPolicy.deadline)
        await Task.yield()

        let settled = await coordinator.settledOutcome()
        XCTAssertNil(settled)
        XCTAssertFalse(fired)
        XCTAssertTrue(sender.texts.isEmpty)
    }

    func testTheSettledOutcomeOfASentAlertIsReturnedAtOnce() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }
        let outcome = try await sent(fall())

        let settled = await coordinator.settledOutcome()
        XCTAssertEqual(settled, outcome)
    }

    // MARK: - Deadline

    func testNothingIsSentBeforeTheDeadline() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in XCTFail("fired early") }

        clock.advance(by: AlertPolicy.deadline - .milliseconds(1))
        await Task.yield()

        XCTAssertTrue(sender.texts.isEmpty)
        XCTAssertFalse(coordinator.hasFired)
    }

    func testDeadlineSendsTheGeneralText() async throws {
        let deadline = expectation(description: "deadline send")
        var received: AlertOutcome?
        coordinator.begin(at: tap, recipients: [ben]) { outcome in
            received = outcome
            deadline.fulfill()
        }

        clock.advance(by: .seconds(10))
        await fulfillment(of: [deadline], timeout: 2)

        let outcome = try XCTUnwrap(received)
        XCTAssertTrue(outcome.isGeneral)
        XCTAssertTrue(outcome.awaitingConfirmation)
        XCTAssertEqual(sender.texts.count, 1)
        XCTAssertTrue(sender.texts[0].hasPrefix("SAKLOLO: "))
        XCTAssertEqual(sender.calls, [ben.phone])
    }

    func testTheDeadlineSendDoesNotWaitForAFreshFix() async throws {
        let deadline = expectation(description: "deadline send")
        coordinator.begin(at: tap, recipients: [ben]) { _ in deadline.fulfill() }

        clock.advance(by: AlertPolicy.deadline)
        await fulfillment(of: [deadline], timeout: 2)

        XCTAssertEqual(locator.waits, [.zero])
    }

    func testAnEarlySendWaitsForAFixButNotPastTheDeadline() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }
        clock.advance(by: .seconds(9))

        _ = await coordinator.send(classification: fall())

        XCTAssertEqual(locator.started, 1)
        XCTAssertEqual(locator.waits, [.seconds(1)])
    }

    func testEmptySummaryCountsAsNothingUnderstood() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall(summary: "  "))

        XCTAssertTrue(outcome.isGeneral)
    }

    // MARK: - Who needs help

    func testTheTextNamesThePersonFromSetupAndCarriesTheTapTime() async throws {
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock, senderName: { "Jayson" })
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(sender.texts[0].hasPrefix("SAKLOLO: Jayson needs help. Papa fell, his head is bleeding. "))
        XCTAssertTrue(sender.texts[0].contains(tap.formatted(date: .omitted, time: .shortened)))
        XCTAssertEqual(outcome.timestamp, tap)
    }

    func testTheGeneralTextNamesThePersonFromSetup() async throws {
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock, senderName: { "Jayson" })
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        _ = try await sent(nil)

        XCTAssertTrue(sender.texts[0].hasPrefix("SAKLOLO: Jayson needs help. Could not say what happened. "))
    }

    // MARK: - Cancel and hold

    func testCancelSendsNothingEver() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in XCTFail("sent after cancel") }

        coordinator.cancel()
        clock.advance(by: .seconds(30))
        await Task.yield()
        let late = await coordinator.send(classification: fall())

        XCTAssertNil(late)
        XCTAssertTrue(sender.texts.isEmpty)
        XCTAssertTrue(sender.calls.isEmpty)
    }

    func testHoldStopsTheDeadlineButTheDockCanStillSend() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in XCTFail("deadline fired while held") }

        coordinator.hold()
        clock.advance(by: .seconds(30))
        await Task.yield()
        XCTAssertTrue(sender.texts.isEmpty)

        let outcome = await coordinator.send(classification: fall())
        XCTAssertNotNil(outcome)
        XCTAssertEqual(sender.texts.count, 1)
    }

    // MARK: - Failures

    func testAFailedTextIsReportedAndLeftUnsentButTheCallIsStillTried() async throws {
        sender.textFails = true
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.sendFailed)
        XCTAssertNil(outcome.records.first?.smsSentAt)
        XCTAssertEqual(sender.calls, [ben.phone])
        let again = await coordinator.send(classification: fall())
        XCTAssertNil(again)
    }

    func testNoFixSendsWithoutALocation() async throws {
        locator.fix = nil
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertNil(outcome.location)
        XCTAssertTrue(outcome.noLocationLastKnown)
        XCTAssertFalse(outcome.message.contains("Location:"))
    }

    func testNoFixSaysSoInTheText() async throws {
        locator.fix = nil
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.message.hasSuffix(" Location unavailable."))
    }

    func testALastKnownFixIsLabelledWithItsTime() async throws {
        let taken = tap.addingTimeInterval(-11 * 60)
        locator.fix = AlertFix(lat: 14.6507, lng: 121.0494, isLastKnown: true, takenAt: taken)
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        let time = taken.formatted(date: .omitted, time: .shortened)
        XCTAssertTrue(outcome.message.contains("Last known location (\(time)): maps.apple.com/?ll=14.6507,121.0494"))
        XCTAssertTrue(outcome.noLocationLastKnown)
    }

    func testAFreshFixIsNotLabelledLastKnown() async throws {
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertFalse(outcome.message.contains("Last known"))
        XCTAssertFalse(outcome.noLocationLastKnown)
    }

    func testTheOutcomeCarriesTheNumbersForTheComposer() async throws {
        coordinator.begin(at: tap, recipients: [lina, ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertEqual(outcome.recipientPhones, [ben.phone, lina.phone])
    }

    // MARK: - No signal (I3)

    func testNoSignalHoldsTheTextInsteadOfSendingIt() async throws {
        let signal = SignalSwitch(on: false)
        let queue = AlertQueue(sender: sender, signal: signal)
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock, signal: signal, queue: queue)
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.queued)
        XCTAssertTrue(sender.texts.isEmpty)
        XCTAssertNil(outcome.records.first?.smsSentAt)
        XCTAssertEqual(queue.latest?.status, .waiting)
        XCTAssertEqual(queue.latest?.outcome.message, outcome.message)
    }

    func testWithSignalTheTextIsHandedOverAndTheQueueWaitsForConfirmation() async throws {
        let queue = AlertQueue(sender: sender, signal: SignalSwitch(on: true))
        coordinator = AlertCoordinator(
            sender: sender, locator: locator, clock: clock, signal: SignalSwitch(on: true), queue: queue
        )
        coordinator.begin(at: tap, recipients: [ben]) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.awaitingConfirmation)
        XCTAssertEqual(sender.texts.count, 1)
        XCTAssertEqual(queue.latest?.status, .confirming)
    }

    func testNoContactsStillSendsThroughTheShortcut() async throws {
        coordinator.begin(at: tap, recipients: []) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.awaitingConfirmation)
        XCTAssertTrue(sender.calls.isEmpty)
        XCTAssertTrue(outcome.records.isEmpty)
    }
}

// MARK: - Fakes at the system boundaries (URL opening, GPS, network, time)

@MainActor
final class SignalSwitch: SignalChecking {
    var hasSignal: Bool
    init(on: Bool) { hasSignal = on }
}

@MainActor
final class RecordingSender: AlertSending {
    struct Failure: Error {}
    var texts: [String] = []
    /// The alert id each text was handed over with.
    var ids: [UUID] = []
    var calls: [String] = []
    var textFails = false
    private var notOpened: [@MainActor () -> Void] = []

    func sendText(_ message: String, id: UUID, notOpened: @escaping @MainActor () -> Void) throws {
        if textFails { throw Failure() }
        texts.append(message)
        ids.append(id)
        self.notOpened.append(notOpened)
    }

    /// iOS reporting, after the fact, that Shortcuts did not open.
    func reportNotOpened() {
        notOpened.last?()
    }

    func call(phone: String) throws {
        calls.append(phone)
    }
}

@MainActor
private final class FakeLocator: AlertLocating {
    var fix: AlertFix?
    /// Suspends before answering, so a second send can run in between.
    var suspends = false
    /// Parks the send in its location wait until `release()`.
    var parks = false
    private var parked: CheckedContinuation<Void, Never>?
    var isParked: Bool { parked != nil }
    private(set) var started = 0
    private(set) var waits: [Duration] = []

    init(fix: AlertFix?) {
        self.fix = fix
    }

    func startFix() {
        started += 1
    }

    func fix(waitingUpTo limit: Duration) async -> AlertFix? {
        waits.append(limit)
        if suspends { await Task.yield() }
        if parks { await withCheckedContinuation { parked = $0 } }
        return fix
    }

    func release() {
        parked?.resume()
        parked = nil
    }
}
