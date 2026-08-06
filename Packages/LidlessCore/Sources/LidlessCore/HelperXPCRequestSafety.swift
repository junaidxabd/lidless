import Foundation

/// Process-local completion policy for one helper XPC request.
///
/// XPC may race its reply and error callbacks, and a peer can accept a request
/// without ever invoking either callback. The app therefore supplies a third,
/// finite timeout outcome and permits exactly one of the three paths to resume
/// its continuation. This gate does not cancel a request already delivered to
/// the helper and is not evidence about the remote mutation's outcome.
public enum HelperXPCRequestSafety {
    public enum Outcome: Sendable, Equatable, CaseIterable {
        case reply
        case transportFailure
        case timeout
    }

    /// A heartbeat starts after the ten-second interval. Twenty-five more
    /// seconds keeps local failure detection ahead of the app's default
    /// 45-second helper watchdog while leaving a ten-second scheduling margin.
    /// The helper still owns authoritative fail-safe restoration.
    public static let replyTimeout: TimeInterval = 25

    public final class CompletionGate: @unchecked Sendable {
        private let lock = NSLock()
        private var winningOutcome: Outcome?

        public init() {}

        /// Returns true only for the first terminal path.
        @discardableResult
        public func claim(_ outcome: Outcome) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard winningOutcome == nil else { return false }
            winningOutcome = outcome
            return true
        }
    }
}
