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
            /// The text went out (by itself, a retry, or the composer).
            case sent(at: Date)
            /// No signal: held and retried (I3).
            case waiting
            /// The Shortcut could not send it; the composer is the way (I1, I2).
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
    private var onSent: [UUID: [(Date) -> Void]] = [:]
    private var timer: Task<Void, Never>?

    init(sender: any AlertSending, signal: any SignalChecking, now: @escaping () -> Date = Date.init) {
        self.sender = sender
        self.signal = signal
        self.now = now
    }

    /// The alert the chat's cards describe: the most recent one.
    var latest: Entry? { entries.last }

    /// True while some text is held for signal.
    var hasWaiting: Bool { entries.contains { $0.status == .waiting } }

    /// Takes an alert as it went out (or did not).
    func record(_ outcome: AlertOutcome) {
        let status: Entry.Status
        switch outcome.delivery {
        case .sent: status = .sent(at: outcome.records.compactMap(\.smsSentAt).first ?? now())
        case .queued: status = .waiting
        case .sendFailed: status = .needsComposer
        }
        entries.append(Entry(outcome: outcome, status: status))
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

    /// Tries every held text once, if there is signal now. A text the
    /// Shortcut cannot send moves to the composer card.
    func retry() {
        guard signal.hasSignal else { return }
        for index in entries.indices where entries[index].status == .waiting {
            do {
                try sender.sendText(entries[index].outcome.message)
                markSent(at: index)
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
    /// foreground, and every `AlertPolicy.retryInterval`.
    private func startRetrying() {
        NetworkMonitor.shared.onSignalReturn = { [weak self] in self?.retry() }
        #if canImport(UIKit)
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
