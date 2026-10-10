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
    /// How often a text held for no signal is tried again (I3). TBD in the
    /// wireframes; 30 s is their proposal.
    static let retryInterval: Duration = .seconds(30)
    /// Sent in place of the location link when there is no fix at all (I4).
    static let noLocationNote = "Location unavailable"
    /// Sent in place of the situation summary when nothing was understood
    /// and no name is stored.
    static let generalSummary = "I need help. I could not say what happened"
    /// Follows "<Name> needs help." when nothing was understood.
    static let generalSummaryNamed = "Could not say what happened"
    /// Where setup stores the person's name (`SetupNamePage`).
    static let userNameKey = "userName"
    /// How long after the person is back in the app (from Shortcuts) the
    /// alert may stay unconfirmed before the composer card takes over. A
    /// Shortcuts x-success callback is what brings the app back, so a
    /// confirmation that is coming arrives at once; a missing shortcut never
    /// calls back at all (see `AlertCallback`).
    static let confirmationWait: Duration = .seconds(3)
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
    /// When the fix was taken, to label a last known one.
    var takenAt: Date? = nil
}

extension AlertFix {
    /// "Last known location (7:31 PM)" for a fix that is not live, else nil.
    var note: String? {
        guard isLastKnown else { return nil }
        guard let takenAt else { return "Last known location" }
        return "Last known location (\(takenAt.formatted(date: .omitted, time: .shortened)))"
    }
}

/// What happened when the alert went out. The chat shows it (T6) and the
/// fallback cards read it (T7).
struct AlertOutcome: Equatable, Sendable {
    enum Delivery: Equatable, Sendable {
        /// Shortcuts was opened with the text. Not yet known to have sent
        /// it: `AlertQueue` tracks whether the shortcut confirms (x-success)
        /// or not (x-error, x-cancel, or silence), so the chat never says
        /// the contacts were told before that.
        case awaitingConfirmation
        /// The Shortcut could not be opened (I1).
        case sendFailed
        /// Held for retry because there is no signal (I3).
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
    /// Numbers of the recipients, contact #1 first, for the composer (I2).
    var recipientPhones: [String] = []
    /// Ties the chat cards and the stored rows to this alert.
    var id = UUID()
    /// The alert's own time (the tap): the time written in the text, and the
    /// one the delivered banner shows, so the two always agree.
    var timestamp = Date.now

    var awaitingConfirmation: Bool { delivery == .awaitingConfirmation }
    var sendFailed: Bool { delivery == .sendFailed }
    var queued: Bool { delivery == .queued }
    var noLocationLastKnown: Bool { location?.isLastKnown ?? true }
}

/// Opens the Shortcut and places the call. `ShortcutSMSService` in the app;
/// a recorder in tests.
@MainActor
protocol AlertSending {
    /// Hands `message` to the Shortcut for alert `id`. Not throwing only
    /// means the hand-off started; the result comes back through
    /// `AlertQueue.resolve`. `notOpened` runs if the hand-off fails later.
    func sendText(_ message: String, id: UUID, notOpened: @escaping @MainActor () -> Void) throws
    func call(phone: String) throws
}

extension ShortcutSMSService: AlertSending {
    func sendText(_ message: String, id: UUID, notOpened: @escaping @MainActor () -> Void) throws {
        try sendViaShortcut(message: message, id: id, notOpened: notOpened)
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
    private let signal: (any SignalChecking)?
    private let queue: AlertQueue?
    private let clock: C
    /// The name entered in setup, read when the alert goes out; nil or
    /// blank when none is stored.
    private let senderName: @MainActor () -> String?

    private var state: State = .idle
    private var tappedAt = Date.now
    private var deadlineAt: C.Instant?
    private var recipients: [AlertRecipient] = []
    private var deadlineTask: Task<Void, Never>?
    private var settling: [CheckedContinuation<AlertOutcome?, Never>] = []

    /// Called once, when a send starts (before the location wait), so the
    /// screen knows the alert is going out even before the outcome is in.
    var onFire: (@MainActor () -> Void)?

    /// `signal` nil means always try to send. `queue` gets every outcome,
    /// so a held text is retried after this screen is gone (I3).
    /// `senderName` names the person in the text ("Jayson needs help.").
    init(
        sender: any AlertSending,
        locator: any AlertLocating,
        clock: C,
        signal: (any SignalChecking)? = nil,
        queue: AlertQueue? = nil,
        senderName: @escaping @MainActor () -> String? = { nil }
    ) {
        self.sender = sender
        self.locator = locator
        self.signal = signal
        self.queue = queue
        self.clock = clock
        self.senderName = senderName
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

    /// The outcome of the alert, waiting for a send in progress to finish;
    /// nil if nothing was sent (not yet, or cancelled first).
    func settledOutcome() async -> AlertOutcome? {
        switch state {
        case .sent(let outcome): return outcome
        case .sending: return await withCheckedContinuation { settling.append($0) }
        default: return nil
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
        onFire?()

        let fix = await locator.fix(waitingUpTo: locationWait())

        let summary = classification?.summary.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isGeneral = summary.isEmpty
        let message = ShortcutSMSService().buildMessage(
            summary: isGeneral ? nil : summary,
            name: senderName(),
            timestamp: tappedAt,
            lat: fix?.lat,
            lng: fix?.lng,
            locationNote: fix == nil ? AlertPolicy.noLocationNote : fix?.note
        )

        // No signal: hold the text for retry instead of losing it (I3).
        // Otherwise hand it to the Shortcut once; whether it went out is
        // only known later (`AlertQueue.resolve`). Never sent twice by itself.
        let id = UUID()
        var delivery = AlertOutcome.Delivery.awaitingConfirmation
        if signal?.hasSignal == false {
            delivery = .queued
        } else {
            do {
                try sender.sendText(message, id: id) { [queue] in queue?.resolve(id, .failed) }
            } catch {
                delivery = .sendFailed
            }
        }

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
                // Stamped once the text is confirmed (`alerts(for:)`).
                AlertOutcome.Record(contactID: $0.contactID, smsSentAt: nil, called: $0.contactID == calledID)
            },
            recipientPhones: recipients.map(\.phone),
            id: id,
            timestamp: tappedAt
        )
        state = .sent(outcome)
        queue?.record(outcome)
        let waiting = settling
        settling = []
        for waiter in waiting { waiter.resume(returning: outcome) }
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
    /// The app's coordinator: the Saklolo Shortcut, the phone's GPS, the
    /// network check, and the app-wide retry queue.
    convenience init(location: LocationService) {
        self.init(
            sender: ShortcutSMSService(),
            locator: LiveAlertLocator(service: location),
            clock: ContinuousClock(),
            signal: NetworkMonitor.shared,
            queue: .shared,
            senderName: { UserDefaults.standard.string(forKey: AlertPolicy.userNameKey) }
        )
    }
}

extension AlertOutcome {
    /// The delivery rows to store on the incident. Rows not sent yet
    /// (`smsSentAt == nil`) are the queue: they are stamped when a retry or
    /// the composer gets the text out. A row whose incident was deleted
    /// meanwhile is left alone.
    @MainActor
    func alerts(for incident: Incident, queue: AlertQueue = .shared) -> [Alert] {
        let rows = records.map {
            Alert(incident: incident, contactID: $0.contactID, smsSentAt: $0.smsSentAt, called: $0.called)
        }
        let unsent = rows.filter { $0.smsSentAt == nil }
        if !unsent.isEmpty {
            queue.whenSent(id) { sentAt in
                for row in unsent where row.isStored { row.smsSentAt = sentAt }
            }
        }
        return rows
    }
}

extension Alert {
    /// False once the row is deleted (directly, or with its incident), so a
    /// late retry never writes to a deleted model.
    var isStored: Bool { modelContext != nil && !isDeleted }
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
        AlertFix(
            lat: location.coordinate.latitude,
            lng: location.coordinate.longitude,
            isLastKnown: isLastKnown,
            takenAt: location.timestamp
        )
    }
}
