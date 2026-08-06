import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper termination safety")
struct HelperTerminationSafetyTests {
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

    @Test func failedSignalRestoreCannotVoluntarilyExitBeforeRetry() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let handler = try section(
            of: source,
            from: "source.setEventHandler { [self] in",
            through: "source.resume()"
        )
        let restore = try #require(handler.range(of: "performRestore("))
        let afterRestore = handler[restore.upperBound...]
        let tick = try section(
            of: source,
            from: "private func tick()",
            through: "// MARK: - Sleep/wake awareness"
        )
        let disarm = try section(
            of: source,
            from: "fileprivate func handleDisarm(",
            through: "fileprivate func handleRepairOverride("
        )
        let restoreParking = try section(
            of: source,
            from: "private func parkRestore(",
            through: "private func scheduleRestoreRetry()"
        )
        let architecture = try repositoryFile("ARCHITECTURE.md")
        let normalizedArchitecture = architecture
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        #expect(handler.contains("terminationRequested = true"))
        #expect(handler.contains("finishTerminationIfSafe()"))
        #expect(!handler.contains("exit(0)"))
        #expect(!afterRestore.contains("exit(0)"))
        #expect(tick.contains("finishTerminationIfSafe()"))
        #expect(source.contains(
            "HelperTerminationSafety.restoreRetryDelay(terminationRequested: terminationRequested)"
        ))
        #expect(!source.contains("nextRestoreAttempt = .now() + 30"))
        #expect(restoreParking.contains("restorePending = record"))
        #expect(restoreParking.contains("scheduleRestoreRetry()"))
        for operation in [".arm", ".repairOverride", ".scheduleWake", ".forceSleep"] {
            #expect(source.contains(
                "HelperTerminationSafety.allows(\(operation), whileTerminationRequested: terminationRequested)"
            ))
        }
        #expect(disarm.contains("performRestore(record, reason:"))
        #expect(!source.contains("termination requested with normal sleep restored"))
        #expect(normalizedArchitecture.contains("no helper-owned recovery remains"))
        #expect(normalizedArchitecture.contains(
            "A no-record exit does not prove the external sleep state"
        ))
    }

    @Test func startupQueuesSignalsBehindRecoveryBeforeExposingXPC() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let start = try section(
            of: source,
            from: "func start()",
            through: "private func ensureWorkDirectory()"
        )
        let synchronousStartup = try #require(start.range(of: "queue.sync"))
        let signalSetup = try #require(start.range(of: "installSignalHandlers()"))
        let recovery = try #require(start.range(of: "recoveryPass()"))
        let workDirectory = try #require(start.range(of: "ensureWorkDirectory()"))
        let wakeLedger = try #require(start.range(of: "loadScheduledWake()"))
        let peerValidation = try #require(start.range(
            of: "XPCPeerPolicy.validatedRequirementForCurrentProcess("
        ))
        let listener = try #require(start.range(
            of: "NSXPCListener(machServiceName: LidlessIDs.helperMachService)"
        ))

        #expect(!start.contains("queue.async"))
        #expect(synchronousStartup.lowerBound < signalSetup.lowerBound)
        #expect(signalSetup.lowerBound < recovery.lowerBound)
        #expect(recovery.lowerBound < workDirectory.lowerBound)
        #expect(workDirectory.lowerBound < wakeLedger.lowerBound)
        #expect(wakeLedger.lowerBound < peerValidation.lowerBound)
        #expect(recovery.lowerBound < listener.lowerBound)
        #expect(peerValidation.lowerBound < listener.lowerBound)
    }

    @Test func bothManagedSignalsAreIgnoredBeforeEitherSourceIsConstructed() throws {
        let source = try repositoryFile("Helper/HelperDaemon.swift")
        let setup = try section(
            of: source,
            from: "private func installSignalHandlers()",
            through: "private func finishTerminationIfSafe()"
        )
        let declarations = try #require(setup.range(
            of: "let terminationSignals = [SIGTERM, SIGINT]"
        ))
        let dispositions = try #require(setup.range(
            of: "for sig in terminationSignals {\n            signal(sig, SIG_IGN)\n        }"
        ))
        let sources = try #require(setup.range(
            of: "for sig in terminationSignals {\n            let source = DispatchSource.makeSignalSource"
        ))

        #expect(declarations.lowerBound < dispositions.lowerBound)
        #expect(dispositions.lowerBound < sources.lowerBound)
        #expect(setup.components(separatedBy: "signal(sig, SIG_IGN)").count - 1 == 1)
        #expect(setup.components(separatedBy: "DispatchSource.makeSignalSource").count - 1 == 1)
    }

    @Test func voluntaryExitRequiresARequestedTerminationAndNoRecoveryState() {
        #expect(HelperTerminationSafety.canVoluntarilyExit(
            terminationRequested: true,
            hasSentinel: false,
            hasPendingRestore: false
        ))

        let rejected: [(Bool, Bool, Bool)] = [
            (false, false, false),
            (true, true, false),
            (true, false, true),
            (true, true, true),
            (false, true, false),
            (false, false, true)
        ]
        for (requested, sentinel, pending) in rejected {
            #expect(!HelperTerminationSafety.canVoluntarilyExit(
                terminationRequested: requested,
                hasSentinel: sentinel,
                hasPendingRestore: pending
            ))
        }
    }

    @Test func requestedTerminationRetriesOnTheNextSupervisionTick() {
        #expect(HelperTerminationSafety.restoreRetryDelay(
            terminationRequested: true
        ) == 0)
        #expect(HelperTerminationSafety.restoreRetryDelay(
            terminationRequested: false
        ) == 30)
    }

    @Test func requestedTerminationAllowsOnlyObservationAndNormalSleepRecovery() {
        for operation in [
            HelperTerminationSafety.Operation.arm,
            .repairOverride,
            .scheduleWake,
            .forceSleep
        ] {
            #expect(!HelperTerminationSafety.allows(
                operation,
                whileTerminationRequested: true
            ))
        }
        for operation in [
            HelperTerminationSafety.Operation.observe,
            .restoreNormalSleep
        ] {
            #expect(HelperTerminationSafety.allows(
                operation,
                whileTerminationRequested: true
            ))
        }
        for operation in HelperTerminationSafety.Operation.allCases {
            #expect(HelperTerminationSafety.allows(
                operation,
                whileTerminationRequested: false
            ))
        }
    }
}
