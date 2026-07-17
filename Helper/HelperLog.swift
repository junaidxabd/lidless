import Foundation
import os
import LidlessCore

/// Dual-sink logging: unified log for live debugging, plus an append-only
/// file under /var/db/lidless that the (unprivileged) app can read and show
/// in its Setup pane — the audit trail for "what did the helper do and when".
///
/// Callable from any thread: the os Logger is thread-safe and all file-sink
/// state (formatter, rotation, enablement) is confined to a private serial
/// queue — which is what the `@unchecked Sendable` asserts.
final class HelperLog: @unchecked Sendable {
    static let maxFileBytes = 512 * 1024

    private let logger = Logger(subsystem: LidlessIDs.helperLabel, category: "daemon")
    private let queue = DispatchQueue(label: "com.lidless.helper.log")

    // Queue-confined.
    private let fileURL = URL(fileURLWithPath: HelperPaths.log)
    private var fileSinkEnabled = true
    private lazy var timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        append("INFO  \(message)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        append("ERROR \(message)")
    }

    func critical(_ message: String) {
        logger.critical("\(message, privacy: .public)")
        append("CRIT  \(message)")
    }

    /// After uninstall removes /var/db/lidless, any further file append
    /// would recreate it — switch to unified-log only. Synchronous so
    /// already-enqueued appends drain before the caller deletes the
    /// directory (the log queue never targets the caller's queue).
    func disableFileSink() {
        queue.sync { self.fileSinkEnabled = false }
    }

    private func append(_ line: String) {
        let stamped = Date()
        queue.async { [self] in
            guard fileSinkEnabled else { return }
            let entry = "\(timestampFormatter.string(from: stamped)) \(line)\n"
            guard let data = entry.data(using: .utf8) else { return }
            let fm = FileManager.default

            try? fm.createDirectory(
                atPath: HelperPaths.workDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755]
            )

            if !fm.fileExists(atPath: fileURL.path) {
                fm.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o644])
            } else if let size = try? fm.attributesOfItem(atPath: fileURL.path)[.size] as? Int,
                      size > Self.maxFileBytes {
                let old = fileURL.deletingLastPathComponent().appendingPathComponent("helper.log.old")
                try? fm.removeItem(at: old)
                try? fm.moveItem(at: fileURL, to: old)
                fm.createFile(atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o644])
            }

            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }
}
