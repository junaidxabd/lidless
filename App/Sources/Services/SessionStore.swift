import Foundation
import LidlessCore

/// Session history plus a crash journal for the in-flight session.
///
/// The active session is checkpointed to `current-session.json` on every
/// sample. If the app dies mid-session, the journal stays unresolved until a
/// live helper reconciliation supplies a truthful end reason.
@MainActor
@Observable
final class SessionStore {
    static let maxSessions = 200

    private(set) var sessions: [KeepAwakeSession] = []
    private(set) var unresolvedSession: KeepAwakeSession?
    /// Load and save failures are independent durability evidence. A later
    /// successful save must not erase a still-unresolved load failure from the
    /// product's visible error channel.
    var lastPersistenceError: String? {
        lastLoadResult.errorMessage ?? lastSaveResult.errorMessage
    }
    private(set) var lastLoadResult: StorePersistenceResult = .notAttempted
    private(set) var lastSaveResult: StorePersistenceResult = .notAttempted

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

        var loadErrors: [String] = []
        let historyURL = Self.historyURL()
        if FileManager.default.fileExists(atPath: historyURL.path) {
            do {
                let data = try Data(contentsOf: historyURL)
                sessions = try IPCCoding.decoder().decode(
                    [KeepAwakeSession].self,
                    from: data
                )
            } catch {
                loadErrors.append(
                    "Session history could not be loaded (\(error.localizedDescription))."
                )
            }
        }

        let currentURL = Self.currentURL()
        if FileManager.default.fileExists(atPath: currentURL.path) {
            do {
                let data = try Data(contentsOf: currentURL)
                unresolvedSession = try IPCCoding.decoder().decode(
                    KeepAwakeSession.self,
                    from: data
                )
            } catch {
                loadErrors.append(
                    "The active-session journal could not be loaded (\(error.localizedDescription))."
                )
            }
        }

        if loadErrors.isEmpty {
            lastLoadResult = .succeeded
        } else {
            let message = loadErrors.joined(separator: " ")
                + " Lidless retained the files; check access to Application Support."
            lastLoadResult = .failed(message)
        }
    }

    @discardableResult
    func append(_ session: KeepAwakeSession) -> StorePersistenceResult {
        // Keep the finalized record as the in-memory crash witness until both
        // history and journal deletion are durable. A failed history write
        // must never make a later arm free to overwrite this evidence.
        if !ephemeral {
            unresolvedSession = session
        }
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
        if sessions.count > Self.maxSessions {
            sessions.removeLast(sessions.count - Self.maxSessions)
        }
        let historyResult = persist()
        guard historyResult == .succeeded else { return historyResult }
        return checkpoint(nil)
    }

    /// Persist the in-flight session (or clear the journal with nil).
    @discardableResult
    func checkpoint(_ current: KeepAwakeSession?) -> StorePersistenceResult {
        guard !ephemeral else { return .notAttempted }
        do {
            if let current {
                _ = try AppPaths.ensureSupportDirectory()
                let data = try IPCCoding.encoder().encode(current)
                try data.write(to: Self.currentURL(), options: .atomic)
                // Mirror the durable journal in memory. New-arm admission is
                // fenced by this witness until archival clears the journal.
                unresolvedSession = current
            } else {
                let url = Self.currentURL()
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                unresolvedSession = nil
            }
            return recordSave(.succeeded)
        } catch {
            let operation = current == nil ? "cleared" : "saved"
            let message = "The active-session journal could not be \(operation) (\(error.localizedDescription)). Session evidence remains in memory; check access to Application Support."
            return recordSave(.failed(message))
        }
    }

    @discardableResult
    func clearHistory() -> StorePersistenceResult {
        let retainedSessions = sessions
        sessions = []
        let result = persist()
        if result.errorMessage != nil {
            // Keep the rows and clear action available for a safe retry. The
            // original history file was never replaced on a failed write.
            sessions = retainedSessions
        }
        return result
    }

    /// Archive only after helper reconciliation has selected a truthful reason.
    /// The journal is deleted strictly after the updated history is durable.
    @discardableResult
    func archiveOrphanedSession(endReason: SessionEndReason) -> StorePersistenceResult {
        guard let orphan = unresolvedSession else { return .succeeded }
        // A failed history decode leaves the original file untouched. Never
        // replace those recoverable bytes with the empty in-memory fallback.
        guard lastLoadResult.errorMessage == nil else {
            return recordSave(.failed(
                lastLoadResult.errorMessage
                    ?? "Session history remains unavailable and was left unchanged."
            ))
        }

        let archiveRecord = SessionArchiveSafety.recordForArchive(
            unresolved: orphan,
            durableHistoryMatch: sessions.first { $0.id == orphan.id },
            proposedEndReason: endReason
        )
        // Preserve the selected truthful reason across a transient history
        // failure so a later retry is deterministic and idempotent.
        unresolvedSession = archiveRecord
        sessions.removeAll { $0.id == archiveRecord.id }
        sessions.insert(archiveRecord, at: 0)
        if sessions.count > Self.maxSessions {
            sessions.removeLast(sessions.count - Self.maxSessions)
        }

        let historyResult = persist()
        guard historyResult == .succeeded else { return historyResult }
        return checkpoint(nil)
    }

    /// Retry an archival whose truthful end reason was already selected.
    /// Replacing the same session ID keeps repeated attempts idempotent.
    @discardableResult
    func retryOrphanedSessionArchive() -> StorePersistenceResult {
        guard let endReason = unresolvedSession?.endReason else {
            return .notAttempted
        }
        return archiveOrphanedSession(endReason: endReason)
    }

    @discardableResult
    private func persist() -> StorePersistenceResult {
        guard !ephemeral else { return .notAttempted }
        do {
            _ = try AppPaths.ensureSupportDirectory()
            let data = try IPCCoding.encoder().encode(sessions)
            try data.write(to: Self.historyURL(), options: .atomic)
            return recordSave(.succeeded)
        } catch {
            let message = "Session history could not be saved (\(error.localizedDescription)). The latest history remains in memory; check access to Application Support."
            return recordSave(.failed(message))
        }
    }

    @discardableResult
    private func recordSave(
        _ result: StorePersistenceResult
    ) -> StorePersistenceResult {
        lastSaveResult = result
        return result
    }
}
