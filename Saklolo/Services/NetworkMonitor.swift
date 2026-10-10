import Foundation
import Network

/// Whether the alert text can go out now (I3). `NetworkMonitor` in the app;
/// a switch in tests.
@MainActor
protocol SignalChecking: AnyObject {
    var hasSignal: Bool { get }
}

/// Watches the phone's network paths for the no-signal fallback (I3).
///
/// iOS has no API for cell signal, so this is a stand-in (plan flag 9): there
/// is signal when any path is up or a cellular interface exists. Only a
/// phone with no path and no cellular radio at all (airplane mode, out of
/// coverage) counts as no signal, so a working SMS line is never held back
/// just because mobile data is off.
@MainActor
final class NetworkMonitor: ObservableObject, SignalChecking {
    static let shared = NetworkMonitor()

    /// Nil until the first path arrives; treated as signal so the first
    /// alert is never held on a guess.
    @Published private(set) var signal: Bool?

    /// Called when signal comes back after being lost. `AlertQueue` owns this
    /// one; anything else uses `addSignalReturnObserver`.
    var onSignalReturn: (@MainActor () -> Void)?

    /// Also called on signal return, after `onSignalReturn` (the database
    /// update check).
    private var signalReturnObservers: [@MainActor () -> Void] = []

    func addSignalReturnObserver(_ observer: @escaping @MainActor () -> Void) {
        signalReturnObservers.append(observer)
    }

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let has = Self.hasSignal(
                pathSatisfied: path.status == .satisfied,
                cellularAvailable: path.availableInterfaces.contains { $0.type == .cellular }
            )
            Task { @MainActor in self?.update(has) }
        }
        monitor.start(queue: DispatchQueue(label: "saklolo.network-monitor"))
    }

    var hasSignal: Bool { signal ?? true }

    /// The rule above, on its own so it can be tested.
    nonisolated static func hasSignal(pathSatisfied: Bool, cellularAvailable: Bool) -> Bool {
        pathSatisfied || cellularAvailable
    }

    private func update(_ has: Bool) {
        let returned = signal == false && has
        signal = has
        guard returned else { return }
        onSignalReturn?()
        signalReturnObservers.forEach { $0() }
    }
}
