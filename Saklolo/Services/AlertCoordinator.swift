import Foundation
import CoreLocation

/// The rules for the single alert text (requirement step 4, F3).
enum AlertPolicy {
    /// The alert goes out no later than this after the tap, with the general
    /// text if nothing was understood by then. The one place the limit lives.
    static let deadline: Duration = .seconds(10)
    /// The longest the send waits for a fresh GPS fix before using the last
    /// known one. Never extends past `deadline`.
    static let locationWait: Duration = .seconds(2)
    /// Sent in place of the situation summary when nothing was understood.
    static let generalSummary = "I need help. I could not say what happened"
}

/// Someone the alert is recorded against. A plain copy of `Contact`, so the
/// coordinator never touches SwiftData.
struct AlertRecipient: Equatable, Sendable {
    var contactID: UUID
    var name: String
    var phone: String
    /// 0 is contact #1, the one who is also called.
    var priority: Int
}

extension AlertRecipient {
    init(_ contact: Contact) {
        self.init(contactID: contact.id, name: contact.name, phone: contact.phone, priority: contact.priority)
    }
}

/// A location for the alert text.
struct AlertFix: Equatable, Sendable {
    var lat: Double
    var lng: Double
    /// True when no fresh fix came in time and an older one is used (I4).
    var isLastKnown: Bool
}

/// What happened when the alert went out. The chat shows it (T6) and the
/// fallback cards read it (T7).
struct AlertOutcome: Equatable, Sendable {
    enum Delivery: Equatable, Sendable {
        /// The Saklolo Shortcut opened with the text.
        case sent
        /// The Shortcut could not be opened (I1).
        case sendFailed
        /// Held for retry when there is no signal (I3). Not produced yet;
        /// the network check comes with the fallback work.
        case queued
    }

    /// One row per recipient, turned into an `Alert` on the incident.
    struct Record: Equatable, Sendable {
        var contactID: UUID
        var smsSentAt: Date?
        var called: Bool
    }

    var delivery: Delivery
    /// The general text went out because nothing was understood in time.
    var isGeneral: Bool
    /// The exact text sent.
    var message: String
    /// Names of the recipients, contact #1 first.
    var recipientNames: [String]
    var location: AlertFix?
    var records: [Record]

    var sent: Bool { delivery == .sent }
    var sentGeneral: Bool { sent && isGeneral }
    var sendFailed: Bool { delivery == .sendFailed }
    var queued: Bool { delivery == .queued }
    var noLocationLastKnown: Bool { location?.isLastKnown ?? true }
}

/// Opens the Shortcut and places the call. `ShortcutSMSService` in the app;
/// a recorder in tests.
@MainActor
protocol AlertSending {
    func sendText(_ message: String) throws
    func call(phone: String) throws
}

extension ShortcutSMSService: AlertSending {
    func sendText(_ message: String) throws {
        try sendViaShortcut(message: message)
    }
}

/// Supplies the alert's location.
@MainActor
protocol AlertLocating: AnyObject {
    /// Called at the tap, so a fresh fix has the most time to arrive.
    func startFix()
    /// A fresh fix if one arrives within `limit`, else the last known one,
    /// else nil.
    func fix(waitingUpTo limit: Duration) async -> AlertFix?
}

/// Sends exactly one alert per session: at the earlier of understanding done
/// and `AlertPolicy.deadline` after the tap.
@MainActor
final class AlertCoordinator<C: Clock> where C.Duration == Duration {
    private enum State {
        case idle
        /// Deadline running.
        case armed
        /// Alone mode: the person decides when it goes (the dock).
        case held
        case sending
        case sent(AlertOutcome)
        case cancelled
    }

    private let sender: any AlertSending
    private let locator: any AlertLocating
    private let clock: C
    private let now: () -> Date

    private var state: State = .idle
    private var tappedAt = Date.now
    private var deadlineAt: C.Instant?
    private var recipients: [AlertRecipient] = []
    private var deadlineTask: Task<Void, Never>?

    init(sender: any AlertSending, locator: any AlertLocating, clock: C, now: @escaping () -> Date = Date.init) {
        self.sender = sender
        self.locator = locator
        self.clock = clock
        self.now = now
    }

    /// The outcome once the alert has gone out (or failed to).
    var outcome: AlertOutcome? {
        if case .sent(let outcome) = state { outcome } else { nil }
    }

    /// True once a send has started; nothing more will be sent.
    var hasFired: Bool {
        switch state {
        case .sending, .sent: true
        default: false
        }
    }

    /// Starts the deadline at the tap. If nothing has been sent when it
    /// passes, the general text goes out and `onDeadline` gets the outcome.
    func begin(
        at tap: Date,
        recipients: [AlertRecipient],
        onDeadline: @escaping @MainActor (AlertOutcome) -> Void
    ) {
        guard case .idle = state else { return }
        state = .armed
        tappedAt = tap
        self.recipients = recipients.sorted { $0.priority < $1.priority }
        let deadline = clock.now.advanced(by: AlertPolicy.deadline)
        deadlineAt = deadline
        locator.startFix()
        deadlineTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(until: deadline, tolerance: nil)
            } catch {
                return
            }
            guard let self, case .armed = self.state else { return }
            if let outcome = await self.fire(classification: nil) {
                onDeadline(outcome)
            }
        }
    }

    /// Sends the alert for what was understood (nil for the general text).
    /// Returns nil when an alert already went out or the session ended:
    /// the alert is sent once only.
    func send(classification: SituationClassification?) async -> AlertOutcome? {
        switch state {
        case .armed, .held: return await fire(classification: classification)
        default: return nil
        }
    }

    /// Stops the deadline without sending: alone mode, where the person's
    /// dock decides (G1). A later `send` still goes out.
    func hold() {
        guard case .armed = state else { return }
        state = .held
        deadlineTask?.cancel()
    }

    /// ✕ Cancel: nothing is sent from now on.
    func cancel() {
        switch state {
        case .sending, .sent: return
        default:
            state = .cancelled
            deadlineTask?.cancel()
        }
    }

    private func fire(classification: SituationClassification?) async -> AlertOutcome? {
        // Claimed before the first await, so a racing deadline or second
        // send sees `.sending` and stops.
        state = .sending
        deadlineTask?.cancel()

        let fix = await locator.fix(waitingUpTo: locationWait())

        let summary = classification?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isGeneral = summary.isEmpty
        let message = ShortcutSMSService().buildMessage(
            summary: isGeneral ? AlertPolicy.generalSummary : summary,
            timestamp: tappedAt,
            lat: fix?.lat,
            lng: fix?.lng
        )

        var delivery = AlertOutcome.Delivery.sent
        do {
            try sender.sendText(message)
        } catch {
            delivery = .sendFailed
        }
        let sentAt = delivery == .sent ? now() : nil

        // The call is independent of the text: try it even if the text failed.
        var calledID: UUID?
        if let first = recipients.first {
            if (try? sender.call(phone: first.phone)) != nil {
                calledID = first.contactID
            }
        }

        let outcome = AlertOutcome(
            delivery: delivery,
            isGeneral: isGeneral,
            message: message,
            recipientNames: recipients.map(\.name),
            location: fix,
            records: recipients.map {
                AlertOutcome.Record(contactID: $0.contactID, smsSentAt: sentAt, called: $0.contactID == calledID)
            }
        )
        state = .sent(outcome)
        return outcome
    }

    /// Up to `AlertPolicy.locationWait`, but never past the deadline.
    private func locationWait() -> Duration {
        guard let deadlineAt else { return .zero }
        let remaining = clock.now.duration(to: deadlineAt)
        return max(.zero, min(AlertPolicy.locationWait, remaining))
    }
}

extension AlertCoordinator where C == ContinuousClock {
    /// The app's coordinator: the Saklolo Shortcut and the phone's GPS.
    convenience init(location: LocationService) {
        self.init(sender: ShortcutSMSService(), locator: LiveAlertLocator(service: location), clock: ContinuousClock())
    }
}

extension AlertOutcome {
    /// The delivery rows to store on the incident.
    func alerts(for incident: Incident) -> [Alert] {
        records.map {
            Alert(incident: incident, contactID: $0.contactID, smsSentAt: $0.smsSentAt, called: $0.called)
        }
    }
}

/// `LocationService` behind `AlertLocating`: asks for a one-shot fix at the
/// tap, then waits for it up to the limit before using the last known one.
@MainActor
final class LiveAlertLocator: AlertLocating {
    private let service: LocationService
    private var requestedAt = Date.distantPast

    init(service: LocationService) {
        self.service = service
    }

    func startFix() {
        requestedAt = .now
        service.requestOneShotLocation()
    }

    func fix(waitingUpTo limit: Duration) async -> AlertFix? {
        let clock = ContinuousClock()
        let end = clock.now.advanced(by: limit)
        while clock.now < end {
            if let fresh = service.lastLocation, fresh.timestamp >= requestedAt {
                return Self.fix(fresh, isLastKnown: false)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        if let fresh = service.lastLocation, fresh.timestamp >= requestedAt {
            return Self.fix(fresh, isLastKnown: false)
        }
        // The system keeps a last known fix even when this app has none.
        guard let last = service.lastLocation ?? CLLocationManager().location else { return nil }
        return Self.fix(last, isLastKnown: true)
    }

    private static func fix(_ location: CLLocation, isLastKnown: Bool) -> AlertFix {
        AlertFix(lat: location.coordinate.latitude, lng: location.coordinate.longitude, isLastKnown: isLastKnown)
    }
}
