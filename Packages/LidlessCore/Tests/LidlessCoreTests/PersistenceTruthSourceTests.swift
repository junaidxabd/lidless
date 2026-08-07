import Foundation
import Testing
@testable import LidlessCore

@Suite("Persistence truth source contracts")
struct PersistenceTruthSourceTests {
    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            let candidate = directory.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
            directory.deleteLastPathComponent()
        }

        throw CocoaError(.fileNoSuchFile)
    }

    private func section(
        of source: String,
        from start: String,
        through end: String
    ) throws -> Substring {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(source.range(
            of: end,
            range: startRange.upperBound..<source.endIndex
        ))
        return source[startRange.lowerBound..<endRange.upperBound]
    }

    @Test func storesExposeLoadAndSaveResultsWithoutSuppressingFailures() throws {
        let config = try repositoryFile("App/Sources/Services/ConfigStore.swift")
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")

        #expect(config.contains("enum StorePersistenceResult: Equatable"))
        #expect(config.contains("private(set) var lastPersistenceError: String?"))
        #expect(sessions.contains("var lastPersistenceError: String?"))
        for source in [config, sessions] {
            #expect(source.contains("private(set) var lastLoadResult: StorePersistenceResult"))
            #expect(source.contains("private(set) var lastSaveResult: StorePersistenceResult"))
            #expect(!source.contains("try?"))
        }
        #expect(config.contains("func persist() -> StorePersistenceResult"))
        #expect(sessions.contains("func checkpoint(_ current: KeepAwakeSession?) -> StorePersistenceResult"))
        #expect(sessions.contains("func append(_ session: KeepAwakeSession) -> StorePersistenceResult"))
    }

    @Test func orphanJournalStaysUnresolvedUntilHelperReconciliation() throws {
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")
        let app = try repositoryFile("App/Sources/AppState.swift")

        #expect(sessions.contains(
            "private(set) var unresolvedSession: KeepAwakeSession?"
        ))
        #expect(sessions.contains(
            "func archiveOrphanedSession(endReason: SessionEndReason) -> StorePersistenceResult"
        ))
        #expect(!sessions.contains("orphan.endReason = .appQuit"))
        #expect(!sessions.contains("recoverOrphanedSession()"))

        let archiveStart = try #require(sessions.range(
            of: "func archiveOrphanedSession(endReason: SessionEndReason)"
        ))
        let archive = sessions[archiveStart.lowerBound...]
        let durableHistory = try #require(archive.range(of: "let historyResult = persist()"))
        let journalClear = try #require(archive.range(
            of: "checkpoint(nil)",
            range: durableHistory.upperBound..<archive.endIndex
        ))
        #expect(durableHistory.lowerBound < journalClear.lowerBound)

        #expect(app.contains("var orphanEndReason: SessionEndReason? = nil"))
        #expect(app.contains("orphanEndReason: .appQuit"))
        #expect(app.contains(
            "sessionStore.archiveOrphanedSession(endReason: orphanEndReason)"
        ))
    }

    @Test func appSurfacesStoreFailuresAtEverySessionWriteBoundary() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")

        #expect(app.contains("private func surfacePersistenceErrors()"))
        #expect(app.contains(
            "surfacePersistenceFailure(checkpointResult)"
        ))
        #expect(app.contains(
            "surfacePersistenceFailure(sessionStore.append(session))"
        ))
        #expect(app.contains("surfacePersistenceErrors()"))
    }

    @Test func simulationPersistenceRemainsEphemeralAndSilent() throws {
        let config = try repositoryFile("App/Sources/Services/ConfigStore.swift")
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")

        for source in [config, sessions] {
            #expect(source.contains("guard !ephemeral else { return .notAttempted }"))
        }
    }

    @Test func unresolvedJournalFencesEveryNewArmUntilDurableArchival() throws {
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")
        let app = try repositoryFile("App/Sources/AppState.swift")
        let menu = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")
        let overview = try repositoryFile("App/Sources/UI/Main/OverviewPane.swift")

        let checkpoint = try section(
            of: sessions,
            from: "func checkpoint(_ current: KeepAwakeSession?)",
            through: "func clearHistory()"
        )
        let checkpointWrite = try #require(checkpoint.range(of: "try data.write("))
        let checkpointWitness = try #require(checkpoint.range(
            of: "unresolvedSession = current",
            range: checkpointWrite.upperBound..<checkpoint.endIndex
        ))
        #expect(checkpointWrite.lowerBound < checkpointWitness.lowerBound)

        let append = try section(
            of: sessions,
            from: "func append(_ session: KeepAwakeSession)",
            through: "func checkpoint(_ current: KeepAwakeSession?)"
        )
        #expect(append.contains("unresolvedSession = session"))

        let archive = try section(
            of: sessions,
            from: "func archiveOrphanedSession(endReason: SessionEndReason)",
            through: "private func persist()"
        )
        let retainedOrphan = try #require(archive.range(
            of: "unresolvedSession = archiveRecord"
        ))
        let durableHistory = try #require(archive.range(of: "let historyResult = persist()"))
        #expect(retainedOrphan.lowerBound < durableHistory.lowerBound)
        #expect(sessions.contains("func retryOrphanedSessionArchive()"))

        #expect(app.contains("var sessionEvidenceRequiresReconciliation: Bool"))
        #expect(app.contains("sessionStore.unresolvedSession != nil"))
        #expect(app.contains("launchReconciliationInFlight"))
        #expect(app.contains("sessionStore.lastLoadResult.errorMessage != nil"))
        #expect(app.contains("sessionStore.lastSaveResult.errorMessage != nil"))

        let begin = try section(
            of: app,
            from: "func beginArmFlow(preset: ArmPreset? = nil)",
            through: "func cancelArmFlow()"
        )
        #expect(begin.contains("guard !sessionEvidenceRequiresReconciliation else"))

        let confirm = try section(
            of: app,
            from: "func confirmArm(expectedIntentID: UUID) async",
            through: "/// The always-available \"Disarm & restore normal sleep\"."
        )
        #expect(confirm.contains("guard !sessionEvidenceRequiresReconciliation else"))

        let schedule = try section(
            of: app,
            from: "private func scheduleAutomationTick()",
            through: "private func maintainScheduledWake()"
        )
        #expect(schedule.contains("!sessionEvidenceRequiresReconciliation"))
        #expect(menu.contains("!state.sessionEvidenceRequiresReconciliation"))
        #expect(overview.contains("!state.sessionEvidenceRequiresReconciliation"))
    }

    @Test func failedArchivalRetriesAndInitialCheckpointFailureRestores() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")
        let model = try repositoryFile(
            "Packages/LidlessCore/Sources/LidlessCore/Session.swift"
        )
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")

        #expect(sessions.contains("func retryOrphanedSessionArchive()"))
        #expect(app.contains("private func retryPendingOrphanArchiveIfNeeded()"))

        let tick = try section(
            of: app,
            from: "private func tick()",
            through: "private func refreshSystemFlags()"
        )
        let retry = try #require(tick.range(of: "retryPendingOrphanArchiveIfNeeded()"))
        let schedule = try #require(tick.range(of: "scheduleAutomationTick()"))
        #expect(retry.lowerBound < schedule.lowerBound)

        let arm = try section(
            of: app,
            from: "let startedAt = Date()",
            through: "} catch {"
        )
        let checkpoint = try #require(arm.range(of: "let checkpointResult"))
        let armed = try #require(arm.range(
            of: "phase = .armed",
            range: checkpoint.upperBound..<arm.endIndex
        ))
        #expect(checkpoint.lowerBound < armed.lowerBound)
        #expect(arm.contains("endReason: .persistenceFailure"))
        #expect(arm.contains("beginRestore(PendingRestore("))
        #expect(model.contains("case persistenceFailure"))
        #expect(history.contains("case .persistenceFailure: \"Session record failure\""))

        let data = try IPCCoding.encoder().encode(SessionEndReason.persistenceFailure)
        #expect(
            try IPCCoding.decoder().decode(SessionEndReason.self, from: data)
                == .persistenceFailure
        )
    }

    @Test func corruptHistoryAndFailedClearNeverDestroyRecoverableEvidence() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")

        let archive = try section(
            of: sessions,
            from: "func archiveOrphanedSession(endReason: SessionEndReason)",
            through: "func retryOrphanedSessionArchive()"
        )
        let loadFence = try #require(archive.range(
            of: "guard lastLoadResult.errorMessage == nil else"
        ))
        let archiveResolution = try #require(archive.range(
            of: "SessionArchiveSafety.recordForArchive("
        ))
        let historyWrite = try #require(archive.range(of: "let historyResult = persist()"))
        #expect(loadFence.lowerBound < archiveResolution.lowerBound)
        #expect(archiveResolution.lowerBound < historyWrite.lowerBound)

        let clear = try section(
            of: sessions,
            from: "func clearHistory()",
            through: "func archiveOrphanedSession(endReason: SessionEndReason)"
        )
        #expect(clear.contains("let retainedSessions = sessions"))
        #expect(clear.contains("sessions = retainedSessions"))
        #expect(app.contains("func clearSessionHistory() -> Bool"))
        #expect(history.contains("if state.clearSessionHistory()"))
    }

    @Test func successfulSessionSaveCannotHideAnUnresolvedLoadFailure() throws {
        let app = try repositoryFile("App/Sources/AppState.swift")
        let sessions = try repositoryFile("App/Sources/Services/SessionStore.swift")

        let visibleError = try section(
            of: sessions,
            from: "var lastPersistenceError: String?",
            through: "private(set) var lastLoadResult: StorePersistenceResult"
        )
        #expect(visibleError.contains("lastLoadResult.errorMessage"))
        #expect(visibleError.contains("lastSaveResult.errorMessage"))

        let recordSave = try section(
            of: sessions,
            from: "private func recordSave(",
            through: "return result"
        )
        #expect(!recordSave.contains("lastPersistenceError ="))

        let clear = try section(
            of: app,
            from: "func clearSessionHistory() -> Bool",
            through: "func refreshPendingProjection()"
        )
        #expect(clear.contains("sessionStore.lastLoadResult.errorMessage"))
        #expect(clear.contains("surfacePersistenceErrors()"))
    }
}
