import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Every alert of this app run, and what became of it (I1 to I4). Lives for
/// the whole app, not the chat screen, so a text held for no signal is still
/// retried after the session ends (I3). The chat cards read it to show the
/// live state of the latest alert.
///
/// Only this run: a text still held when the app is killed stays as unsent
/// rows (`Alert.smsSentAt == nil`) and is not retried after relaunch.
@MainActor
final class AlertQueue: ObservableObject {
    struct Entry: Identifiable, Equatable {
        enum Status: Equatable {
            /// The text went out: the Shortcut confirmed it (x-success), or the
            /// person sent it from the composer.
            case sent(at: Date)
            /// Handed to the Shortcut; waiting for it to say it ran. Nothing
            /// may claim the contacts were told while in this state.
            case confirming
            /// No signal: held and retried (I3).
            case waiting
            /// The Shortcut could not send it, said it failed or was cancelled,
            /// or never confirmed; the composer is the way (I1, I2).
            case needsComposer
        }

        var outcome: AlertOutcome
        var status: Status
        var id: UUID { outcome.id }
    }

    /// The app's queue: the Saklolo Shortcut and the phone's network.
    static let shared: AlertQueue = {
        let queue = AlertQueue(sender: ShortcutSMSService(), signal: NetworkMonitor.shared)
        queue.startRetrying()
        return queue
    }()

    @Published private(set) var entries: [Entry] = []

    private let sender: any AlertSending
    private let signal: any SignalChecking
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void
    private var onSent: [UUID: [(Date) -> Void]] = [:]
    private var timer: Task<Void, Never>?
    /// Callbacks that came in before their alert was recorded.
    private var early: [UUID: AlertCallback.Result] = [:]
    /// Alerts still confirming when the app went to the background (to
    /// Shortcuts, normally).
    private var leftApp: Set<UUID> = []
    private var confirmationTimeouts: [UUID: Task<Void, Never>] = [:]

    /// `sleep` waits out `AlertPolicy.confirmationWait`; a test clock in tests.
    init(
        sender: any AlertSending,
        signal: any SignalChecking,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.sender = sender
        self.signal = signal
        self.now = now
        self.sleep = sleep
    }

    /// The alert the chat's cards describe: the most recent one.
    var latest: Entry? { entries.last }

    /// Where alert `id` is, or nil if it is not in the queue.
    func status(of id: UUID) -> Entry.Status? {
        entries.first { $0.id == id }?.status
    }

    /// True while some text is held for signal.
    var hasWaiting: Bool { entries.contains { $0.status == .waiting } }

    /// Takes an alert as it went out (or did not).
    func record(_ outcome: AlertOutcome) {
        let status: Entry.Status
        switch outcome.delivery {
        case .awaitingConfirmation: status = .confirming
        case .queued: status = .waiting
        case .sendFailed: status = .needsComposer
        }
        entries.append(Entry(outcome: outcome, status: status))
        if let result = early.removeValue(forKey: outcome.id) {
            resolve(outcome.id, result)
        }
    }

    // MARK: - Confirmation

    /// What the Shortcut reported for alert `id`. Only x-success counts as
    /// sent. A failure or cancel moves a confirming alert to the composer;
    /// nothing is resent by itself. A late x-success still marks it sent,
    /// since the text did go out.
    func resolve(_ id: UUID, _ result: AlertCallback.Result) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            early[id] = result
            return
        }
        confirmationTimeouts.removeValue(forKey: id)?.cancel()
        leftApp.remove(id)
        switch (entries[index].status, result) {
        case (.sent, _): return
        case (_, .sent): markSent(at: index)
        case (.confirming, .failed), (.confirming, .cancelled): entries[index].status = .needsComposer
        default: return
        }
    }

    /// A `saklolo://` URL opened the app. True if it was an alert callback.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let (id, result) = AlertCallback.parse(url) else { return false }
        resolve(id, result)
        return true
    }

    /// The app went to the background: Shortcuts opened, normally.
    func appLeft() {
        for entry in entries where entry.status == .confirming {
            leftApp.insert(entry.id)
        }
    }

    /// The person is back in the app. An alert that left for Shortcuts and
    /// is still unconfirmed `AlertPolicy.confirmationWait` from now goes to
    /// the composer card: no callback is what a missing shortcut looks like.
    func appReturned() {
        for entry in entries where entry.status == .confirming && leftApp.contains(entry.id) {
            let id = entry.id
            guard confirmationTimeouts[id] == nil else { continue }
            confirmationTimeouts[id] = Task { [weak self, sleep] in
                do { try await sleep(AlertPolicy.confirmationWait) } catch { return }
                self?.confirmationTimedOut(id)
            }
        }
    }

    private func confirmationTimedOut(_ id: UUID) {
        confirmationTimeouts[id] = nil
        leftApp.remove(id)
        guard let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].status == .confirming else { return }
        entries[index].status = .needsComposer
    }

    /// Runs `action` with the send time once the alert's text has gone out;
    /// at once if it already has.
    func whenSent(_ id: UUID, _ action: @escaping (Date) -> Void) {
        if case .sent(let at)? = entries.first(where: { $0.id == id })?.status {
            action(at)
        } else {
            onSent[id, default: []].append(action)
        }
    }

    /// Hands every held text to the Shortcut once, if there is signal now.
    /// It then waits for confirmation like the first try; a text the
    /// Shortcut cannot take moves to the composer card.
    func retry() {
        guard signal.hasSignal else { return }
        for index in entries.indices where entries[index].status == .waiting {
            let id = entries[index].id
            do {
                try sender.sendText(entries[index].outcome.message, to: entries[index].outcome.recipientPhones, id: id) { [weak self] in
                    self?.resolve(id, .failed)
                }
                entries[index].status = .confirming
            } catch {
                entries[index].status = .needsComposer
            }
        }
    }

    /// The person sent the text from the message composer (I2).
    func composerSent(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        if case .sent = entries[index].status { return }
        markSent(at: index)
    }

    private func markSent(at index: Int) {
        let at = now()
        entries[index].status = .sent(at: at)
        let id = entries[index].id
        for action in onSent.removeValue(forKey: id) ?? [] { action(at) }
    }

    // MARK: - Live retry triggers

    /// Retries when signal returns, when the app comes back to the
    /// foreground, and every `AlertPolicy.retryInterval`. Also watches the
    /// app leave for Shortcuts and come back, for the confirmation wait.
    private func startRetrying() {
        NetworkMonitor.shared.onSignalReturn = { [weak self] in self?.retry() }
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.appLeft() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.appReturned() }
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retry() }
        }
        #endif
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: AlertPolicy.retryInterval)
                guard let self else { return }
                if self.hasWaiting { self.retry() }
            }
        }
    }
}
