import Foundation
import os

/// Runs `work` and returns its result, or nil once `timeout` has passed,
/// whichever comes first. The deadline holds even when `work` ignores
/// cancellation (a task group would wait for it): `work` runs in its own
/// task, is cancelled at the deadline, and its late result is dropped.
func firstResult<T: Sendable>(
    within timeout: Duration,
    _ work: @escaping @Sendable () async -> T?
) async -> T? {
    let finished = OSAllocatedUnfairLock(initialState: false)
    return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        let finish: @Sendable (T?) -> Void = { value in
            let first = finished.withLock { done -> Bool in
                guard !done else { return false }
                done = true
                return true
            }
            if first { continuation.resume(returning: value) }
        }
        let worker = Task { finish(await work()) }
        Task {
            try? await Task.sleep(for: timeout)
            worker.cancel()
            finish(nil)
        }
    }
}
