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
        coordinator = AlertCoordinator(sender: sender, locator: locator, clock: clock, now: { [tap] in tap.addingTimeInterval(4) })
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
        XCTAssertTrue(outcome.sent)
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
        XCTAssertTrue(outcome.records.allSatisfy { $0.smsSentAt == tap.addingTimeInterval(4) })
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
        XCTAssertTrue(outcome.sentGeneral)
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

        XCTAssertTrue(outcome.sentGeneral)
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

    func testNoContactsStillSendsThroughTheShortcut() async throws {
        coordinator.begin(at: tap, recipients: []) { _ in }

        let outcome = try await sent(fall())

        XCTAssertTrue(outcome.sent)
        XCTAssertTrue(sender.calls.isEmpty)
        XCTAssertTrue(outcome.records.isEmpty)
    }
}

// MARK: - Fakes at the system boundaries (URL opening, GPS, time)

@MainActor
private final class RecordingSender: AlertSending {
    struct Failure: Error {}
    var texts: [String] = []
    var calls: [String] = []
    var textFails = false

    func sendText(_ message: String) throws {
        if textFails { throw Failure() }
        texts.append(message)
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
        return fix
    }
}
