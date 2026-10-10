import CryptoKit
import Foundation

/// Fetches a newer signed database when there is signal, at most every six
/// hours, and hands it to the store. Never in the way of an alert:
/// `trigger()` returns at once, nothing on the alert path awaits a check, a
/// check gives up at `hardBound`, and a failure is silent (the database in
/// use simply stays).
@MainActor
final class DatabaseUpdater {
    /// The app's updater, or nil while no public key is bundled: then no
    /// request is ever made and the bundled database is all there is.
    static let shared: DatabaseUpdater? = DatabasePublicKey.bundled().map {
        DatabaseUpdater(publicKey: $0, signal: NetworkMonitor.shared)
    }

    private let fetcher: any DatabaseFetching
    private let store: DatabaseStore
    private let publicKey: Curve25519.Signing.PublicKey?
    private let signal: any SignalChecking
    private let now: () -> Date
    private let defaults: UserDefaults
    private let minInterval: TimeInterval
    private let hardBound: Duration

    private var inFlight: Task<Void, Never>?
    /// In memory only: after a relaunch one more attempt is fine.
    private var lastAttempt: Date?

    init(
        fetcher: any DatabaseFetching = URLSessionDatabaseFetcher(),
        store: DatabaseStore = .shared,
        publicKey: Curve25519.Signing.PublicKey?,
        signal: any SignalChecking,
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard,
        minInterval: TimeInterval = DatabaseUpdateConfig.minInterval,
        hardBound: Duration = DatabaseUpdateConfig.hardBound
    ) {
        self.fetcher = fetcher
        self.store = store
        self.publicKey = publicKey
        self.signal = signal
        self.now = now
        self.defaults = defaults
        self.minInterval = minInterval
        self.hardBound = hardBound
    }

    var isChecking: Bool { inFlight != nil }

    /// Starts a check in the background if one is due; returns immediately.
    func trigger() {
        _ = start()
    }

    /// The same as `trigger()`, but waits for the check (tests).
    func checkNow() async {
        await start()?.value
    }

    /// Due: a key to verify with, signal, nothing running, six hours since
    /// the last completed check and a minute since the last attempt.
    private var isDue: Bool {
        guard publicKey != nil, signal.hasSignal, inFlight == nil else { return false }
        let time = now()
        if let last = defaults.object(forKey: DatabaseUpdateConfig.lastCompletedCheckKey) as? Date,
           time.timeIntervalSince(last) < minInterval { return false }
        if let lastAttempt, time.timeIntervalSince(lastAttempt) < DatabaseUpdateConfig.retryInterval { return false }
        return true
    }

    private func start() -> Task<Void, Never>? {
        guard isDue, let publicKey else { return nil }
        lastAttempt = now()
        let fetcher = fetcher, store = store, hardBound = hardBound
        let task = Task.detached(priority: .utility) { [weak self] in
            let completed = await firstResult(within: hardBound) {
                await Self.check(fetcher: fetcher, store: store, publicKey: publicKey)
            } ?? false
            await self?.finish(completed: completed)
        }
        inFlight = task
        return task
    }

    private func finish(completed: Bool) {
        inFlight = nil
        // A thrown fetch or a timeout is not a completed check, so the next
        // signal return or foreground tries again.
        if completed { defaults.set(now(), forKey: DatabaseUpdateConfig.lastCompletedCheckKey) }
    }

    /// True when both files arrived, whatever the store then decided.
    nonisolated private static func check(fetcher: any DatabaseFetching, store: DatabaseStore,
                                          publicKey: Curve25519.Signing.PublicKey) async -> Bool {
        guard let payload = await body(of: DatabaseUpdateConfig.databaseURL, from: fetcher),
              let signature = await body(of: DatabaseUpdateConfig.signatureURL, from: fetcher) else {
            print("[database] update check failed; keeping version \(store.active.version)")
            return false
        }
        let result = store.apply(payload: payload, signature: signature, publicKey: publicKey)
        print("[database] update check: \(result); using version \(store.active.version)")
        return true
    }

    nonisolated private static func body(of url: URL, from fetcher: any DatabaseFetching) async -> Data? {
        guard let data = try? await fetcher.fetch(DatabaseUpdateConfig.request(for: url)),
              data.count <= DatabaseUpdateConfig.maxResponseBytes else { return nil }
        return data
    }
}
