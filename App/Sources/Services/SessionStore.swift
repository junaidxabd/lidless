import Foundation
import LidlessCore

/// Session history plus a crash journal for the in-flight session.
///
/// The active session is checkpointed to `current-session.json` on every
/// sample; if the app dies mid-session, next launch folds that file into
/// history with `.appQuit` — the battery curve survives, and History never
/// shows a phantom "still running" entry.
@MainActor
@Observable
final class SessionStore {
    static let maxSessions = 200

    private(set) var sessions: [KeepAwakeSession] = []

    private static func historyURL() -> URL {
        AppPaths.supportDirectory().appendingPathComponent("sessions.json")
    }

    private static func currentURL() -> URL {
        AppPaths.supportDirectory().appendingPathComponent("current-session.json")
    }

    /// Simulation/dry-run keeps history in memory only — simulated sessions
    /// must never pollute the real record.
    private let ephemeral: Bool

    init(ephemeral: Bool = false) {
        self.ephemeral = ephemeral
        guard !ephemeral else { return }
        if let data = try? Data(contentsOf: Self.historyURL()),
           let loaded = IPCCoding.decode([KeepAwakeSession].self, from: data) {
            sessions = loaded
        }
        recoverOrphanedSession()
    }

    func append(_ session: KeepAwakeSession) {
        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions.removeLast(sessions.count - Self.maxSessions)
        }
        persist()
        checkpoint(nil)
    }

    /// Persist the in-flight session (or clear the journal with nil).
    func checkpoint(_ current: KeepAwakeSession?) {
        guard !ephemeral else { return }
        _ = AppPaths.ensureSupportDirectory()
        if let current {
            try? IPCCoding.encoder().encode(current).write(to: Self.currentURL(), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.currentURL())
        }
    }

    func clearHistory() {
        sessions = []
        persist()
    }

    private func recoverOrphanedSession() {
        guard let data = try? Data(contentsOf: Self.currentURL()),
              var orphan = IPCCoding.decode(KeepAwakeSession.self, from: data)
        else { return }

        orphan.endedAt = orphan.samples.last?.time ?? orphan.startedAt
        orphan.endReason = .appQuit
        orphan.endPercent = orphan.samples.last.map { Int($0.percent.rounded()) } ?? orphan.startPercent
        sessions.insert(orphan, at: 0)
        persist()
        checkpoint(nil)
    }

    private func persist() {
        guard !ephemeral else { return }
        _ = AppPaths.ensureSupportDirectory()
        try? IPCCoding.encoder().encode(sessions).write(to: Self.historyURL(), options: .atomic)
    }
}
