import Foundation
import Observation

/// The rules for alone mode's dock (G1, G2, G5). Nothing is sent at
/// understanding; "I need help" counts down and sends when it runs out or is
/// tapped, and the "I'm okay" slide cancels it before it goes.
enum AloneModePolicy {
    /// How long "I need help" counts down before the alert goes on its own.
    /// TBD in WIREFRAMES.md (plan flag 9); the one place the length lives.
    static let countdown: Duration = .seconds(10)
    /// How far the "I'm okay" knob must travel, as a share of the track, for
    /// the slide to count. Short of it the knob springs back, so a stray
    /// touch cannot cancel the alert.
    static let slideThreshold = 0.85

    /// Share of the track covered by a drag, clamped to 0...1.
    static func slideFraction(translation: Double, travel: Double) -> Double {
        guard travel > 0 else { return 0 }
        return min(max(translation / travel, 0), 1)
    }

    /// True when a released slide has gone far enough to mean "I'm okay".
    static func slideCompletes(fraction: Double) -> Bool {
        fraction >= slideThreshold
    }

    /// "0:10" for the countdown bar. Whole seconds rounded up, so the bar
    /// reads 0:01 until the very end rather than 0:00 early.
    static func clockText(_ remaining: Duration) -> String {
        let (seconds, attoseconds) = remaining.components
        let whole = max(0, Int(seconds) + (attoseconds > 0 ? 1 : 0))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }
}

/// The "I need help" countdown. Fires exactly once: when it runs out, or on
/// `fireNow()`. `okay()` stops it first, and then it never fires.
@MainActor
@Observable
final class AloneCountdown<C: Clock> where C.Duration == Duration {
    enum State: Equatable {
        case idle
        case running
        /// The alert was asked for (countdown ran out or the bar was tapped).
        case fired
        /// "I'm okay" before the alert: nothing is sent.
        case okay
        /// Stopped without either, e.g. the screen went away.
        case stopped
    }

    let total: Duration
    private(set) var state: State = .idle
    private(set) var remaining: Duration

    @ObservationIgnored private let clock: C
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var onFire: (@MainActor () -> Void)?

    init(clock: C, total: Duration = AloneModePolicy.countdown) {
        self.clock = clock
        self.total = total
        self.remaining = total
    }

    /// Share of the countdown still left, 1 at the start and 0 at the end.
    var fractionLeft: Double {
        guard total > .zero else { return 0 }
        return min(max(remaining / total, 0), 1)
    }

    /// Starts counting from now. `onFire` is called once, when it runs out
    /// or the bar is tapped. Starting again does nothing.
    func start(onFire: @escaping @MainActor () -> Void) {
        guard state == .idle else { return }
        state = .running
        self.onFire = onFire
        let begin = clock.now
        let deadline = begin.advanced(by: total)
        task = Task { [weak self, clock] in
            // Ticks are counted from the start, not from when each wake-up
            // lands, so the bar never drifts and a late wake still ends on time.
            var next = begin
            while true {
                next = min(next.advanced(by: .seconds(1)), deadline)
                do {
                    try await clock.sleep(until: next, tolerance: nil)
                } catch {
                    return
                }
                guard let self, self.state == .running else { return }
                let left = clock.now.duration(to: deadline)
                self.remaining = max(.zero, left)
                if next == deadline || left <= .zero {
                    self.fire()
                    return
                }
            }
        }
    }

    /// The bar was tapped: send now.
    func fireNow() {
        fire()
    }

    /// The slide completed. True if this stopped the alert before it went;
    /// false if it had already fired (or the countdown was not running).
    @discardableResult
    func okay() -> Bool {
        guard state == .running else { return false }
        state = .okay
        finish()
        return true
    }

    /// The dock went away: stop quietly, neither firing nor counting as okay.
    func stop() {
        guard state == .running || state == .idle else { return }
        state = .stopped
        finish()
    }

    private func fire() {
        guard state == .running else { return }
        state = .fired
        remaining = .zero
        let onFire = self.onFire
        finish()
        onFire?()
    }

    private func finish() {
        task?.cancel()
        task = nil
        onFire = nil
    }
}
