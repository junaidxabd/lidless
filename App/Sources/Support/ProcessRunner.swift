import Foundation

/// Async wrapper for short-lived commands (`pmset -g therm` etc.). Output is
/// read in the termination handler — safe for the tiny outputs involved.
enum ProcessRunner {
    struct Failure: Error, CustomStringConvertible {
        let command: String
        let status: Int32
        let output: String
        var description: String { "\(command) exited \(status): \(output)" }
    }

    static func run(
        _ executable: String,
        _ arguments: [String],
        timeout: TimeInterval = 30
    ) async throws -> String {
        let resumed = ResumedFlag()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.terminationHandler = { finished in
                    // Post-exit read: outputs here are far below the 64KB
                    // pipe buffer, so the child can never block writing.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    guard resumed.claim() else { return }
                    if finished.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: Failure(
                            command: ([executable] + arguments).joined(separator: " "),
                            status: finished.terminationStatus,
                            output: output
                        ))
                    }
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    if resumed.claim() {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                // Deadline: a wedged child must not hang the caller forever.
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    kill(process.processIdentifier, SIGKILL)
                    if resumed.claim() {
                        continuation.resume(throwing: Failure(
                            command: ([executable] + arguments).joined(separator: " "),
                            status: -1,
                            output: "timed out after \(Int(timeout))s"
                        ))
                    }
                }
            }
        } onCancel: {
            // Best effort; the deadline path cleans up stragglers.
        }
    }
}

private final class ResumedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
