import Foundation
import Testing
@testable import LidlessCore

@Suite("Scheduled wake ledger adapter")
struct ScheduledWakeLedgerAdapterTests {
    @Test func helperPersistsEveryTransactionBoundaryBeforeSuccess() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let schedule = try section(
            of: helper,
            from: "fileprivate func handleScheduleWake(",
            through: "fileprivate func handleLegacyScheduleWake("
        )

        for required in [
            "ScheduledWakeLedger",
            "persistScheduledWakeLedger(",
            "PMSet.readScheduledWakes()",
            "beginScheduling(",
            "confirmScheduled(",
            "prepareCancellation(",
            "completeCancellation(",
            "nextAction(observedEvents:",
        ] {
            #expect(helper.contains(required))
        }

        let begin = try #require(schedule.range(of: "beginScheduling("))
        let persistIntent = try #require(schedule.range(
            of: "try commitScheduledWakeLedger(candidate)"
        ))
        let mutate = try #require(schedule.range(of: "PMSet.scheduleWake("))
        let observe = try #require(schedule.range(
            of: "PMSet.readScheduledWakes()"
        ))
        let confirm = try #require(schedule.range(of: "confirmScheduled("))
        let success = try #require(schedule.range(of: "reply(replyData(ok: true))"))
        #expect(begin.lowerBound < persistIntent.lowerBound)
        #expect(persistIntent.lowerBound < mutate.lowerBound)
        #expect(mutate.lowerBound < observe.lowerBound)
        #expect(observe.lowerBound < confirm.lowerBound)
        #expect(confirm.lowerBound < success.lowerBound)
        #expect(!schedule.contains("try?"))
    }

    @Test func persistenceAndParsingFailuresRemainExplicit() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let pmset = try repositoryFile("Helper/PMSet.swift")

        #expect(pmset.contains("static func readScheduledWakes() throws"))
        #expect(pmset.contains("try ScheduledWakeOutputParser.parse(output)"))
        #expect(helper.contains("scheduledWakeLedgerFailure"))
        #expect(helper.contains("loadScheduledWakeLedger()"))
        #expect(helper.contains("reconcileScheduledWakeLedger("))
        #expect(!helper.contains("private func persistScheduledWake()"))
        #expect(!helper.contains("try? IPCCoding.encode(scheduledWake)"))
    }

    @Test func wakeRecoveryMarkerCoversIntentThroughFinalProofAndLaunchd() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let launchd = try repositoryFile(
            "Helper/Resources/com.lidless.helper.plist"
        )
        let schedule = try section(
            of: helper,
            from: "if let date = request.desiredDate {",
            through: "reply(replyData(ok: true))"
        )

        #expect(
            HelperPaths.scheduledWakeReconciliationMarkerFilename
                == "scheduled-wake-recovery-required.json"
        )
        #expect(launchd.contains(
            "/var/db/lidless/scheduled-wake-recovery-required.json"
        ))

        let marker = try #require(schedule.range(
            of: "try ensureScheduledWakeReconciliationMarker()"
        ))
        let pendingCommit = try #require(schedule.range(
            of: "try commitScheduledWakeLedger(candidate)"
        ))
        let mutation = try #require(schedule.range(of: "PMSet.scheduleWake("))
        let finalProof = try #require(schedule.range(
            of: "try finishScheduledWakeReconciliation("
        ))
        let success = try #require(schedule.range(of: "reply(replyData(ok: true))"))
        #expect(marker.lowerBound < pendingCommit.lowerBound)
        #expect(pendingCommit.lowerBound < mutation.lowerBound)
        #expect(mutation.lowerBound < finalProof.lowerBound)
        #expect(finalProof.lowerBound < success.lowerBound)
    }

    @Test func launchAndTickYieldAfterOneRecoveryAction() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let start = try section(
            of: helper,
            from: "func start() {",
            through: "private func recoveryPass("
        )
        let tick = try section(
            of: helper,
            from: "private func tick() {",
            through: "// MARK: - Sleep/wake awareness"
        )
        let client = try section(
            of: helper,
            from: "fileprivate func handleScheduleWake(",
            through: "fileprivate func handleLegacyScheduleWake("
        )

        #expect(start.contains("maximumActions: 1"))
        #expect(tick.contains("maximumActions: 1"))
        #expect(client.contains("maximumActions: 64"))
        #expect(helper.contains("case needsMoreWork"))
    }

    @Test func absentLedgerResolvesOnlyAnUnlaunchedWakeTransaction() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let load = try section(
            of: helper,
            from: "private func loadScheduledWakeLedger() throws {",
            through: "// MARK: - NSXPCListenerDelegate"
        )

        let commandUncertainty = try #require(load.range(
            of: "if durableMutationMarkerRequiresRecovery"
        ))
        let absenceResolution = try #require(load.range(
            of: "try clearScheduledWakeReconciliationMarkerAfterProof()"
        ))
        #expect(commandUncertainty.lowerBound < absenceResolution.lowerBound)
        #expect(load.contains(
            "a durable command marker exists without its required ledger"
        ))
    }

    @Test func legacyMigrationPublishesRecoveryMarkerBeforePendingLedger() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let load = try section(
            of: helper,
            from: "private func loadScheduledWakeLedger() throws {",
            through: "// MARK: - NSXPCListenerDelegate"
        )

        let migration = try #require(load.range(of: "var migrated = ScheduledWakeLedger()"))
        let migrationTail = load[migration.lowerBound..<load.endIndex]
        let marker = try #require(migrationTail.range(
            of: "try ensureScheduledWakeReconciliationMarker()"
        ))
        let persist = try #require(migrationTail.range(
            of: "try persistScheduledWakeLedger(migrated)"
        ))
        let assign = try #require(migrationTail.range(
            of: "scheduledWakeLedger = migrated"
        ))
        #expect(marker.lowerBound < persist.lowerBound)
        #expect(persist.lowerBound < assign.lowerBound)
    }

    @Test func allAutomaticCleanupSelectorsAreMutationFreeRefusals() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let client = try repositoryFile("App/Sources/Helper/HelperClient.swift")

        let prepare = try section(
            of: helper,
            from: "fileprivate func handlePrepareUninstall(",
            through: "fileprivate func handleUninstall("
        )
        let commit = try section(
            of: helper,
            from: "fileprivate func handleUninstall(",
            through: "fileprivate func handleLegacyUninstall("
        )
        let legacy = try section(
            of: helper,
            from: "fileprivate func handleLegacyUninstall(",
            through: "private func currentStatus()"
        )

        for source in [String(prepare), String(commit), String(legacy)] {
            #expect(source.contains("reviewed removal procedure is required"))
            #expect(!source.contains("performRestore("))
            #expect(!source.contains("PMSet."))
            #expect(!source.contains("removeItem"))
            #expect(!source.contains("unlink"))
        }

        let publicUninstall = try section(
            of: client,
            from: "    func uninstall() async throws {",
            through: "    // MARK: - XPC surface"
        )
        #expect(publicUninstall.contains("reviewed removal procedure is required"))
        #expect(!publicUninstall.contains("await uninstall("))
    }

    private func repositoryFile(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
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
}
