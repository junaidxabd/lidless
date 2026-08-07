import Foundation
import Testing
@testable import LidlessCore

@Suite("Managed pmset restoration safety")
struct ManagedSettingRestorationSafetyTests {
    private func sentinel(
        version: Int = OverrideSentinel.currentVersion,
        lowPowerModeKey: String? = nil,
        lowPowerMode: [String: Int]? = nil,
        tcpKeepAlive: [String: Int]? = nil
    ) -> OverrideSentinel {
        OverrideSentinel(
            version: version,
            armedAt: Date(timeIntervalSince1970: 1_700_000_000),
            watchdogTTL: 45,
            watchdogDeadline: Date(timeIntervalSince1970: 1_700_000_045),
            priorSleepDisabled: false,
            priorLowPowerMode: lowPowerMode,
            lowPowerModeKey: lowPowerModeKey,
            priorTCPKeepAlive: tcpKeepAlive
        )
    }

    @Test func capturesOnlyNumericPriorsFromSupportedPowerScopes() {
        let custom = """
        Battery Power:
         lowpowermode 0
        AC Power:
         lowpowermode unavailable
        UPS Power:
         lowpowermode 2
        Future Power:
         lowpowermode 1
        """

        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "lowpowermode",
            fromCustom: custom
        ) == [
            "Battery Power": 0,
            "UPS Power": 2,
        ])
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "not-managed",
            fromCustom: custom
        ) == nil)
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "tcpkeepalive",
            fromCustom: custom
        ) == nil)
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "lowpowermode",
            fromCustom: "Future Power:\n lowpowermode 1"
        ) == nil)
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "lowpowermode",
            fromCustom: "Battery Power:\n lowpowermode unavailable"
        ) == nil)

        let otherKeys = """
        Battery Power:
         powermode 2
         tcpkeepalive 0
        AC Power:
         powermode 1
         tcpkeepalive 1
        """
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "powermode",
            fromCustom: otherKeys
        ) == ["Battery Power": 2, "AC Power": 1])
        #expect(ManagedSettingRestorationSafety.capturedPriors(
            for: "tcpkeepalive",
            fromCustom: otherKeys
        ) == ["Battery Power": 0, "AC Power": 1])
    }

    @Test func legacyOptionalSentinelCannotClaimScopedRestorationSemantics() throws {
        let legacyWithoutOptions = sentinel(version: 1)
        let legacyWithOptions = sentinel(
            version: 1,
            lowPowerModeKey: "lowpowermode",
            lowPowerMode: ["Battery Power": 0]
        )
        let future = sentinel(version: OverrideSentinel.currentVersion + 1)
        let corruptFallback = sentinel(version: 0)

        let compatibleRecovery = try #require(
            ManagedSettingRestorationSafety.plan(
                for: legacyWithoutOptions,
                target: .restoration
            )
        )
        #expect(compatibleRecovery.isEmpty)
        #expect(ManagedSettingRestorationSafety.plan(
            for: legacyWithoutOptions,
            target: .activation
        ) == nil)
        #expect(ManagedSettingRestorationSafety.plan(
            for: legacyWithOptions,
            target: .restoration
        ) == nil)
        #expect(ManagedSettingRestorationSafety.plan(
            for: future,
            target: .restoration
        ) == nil)
        #expect(ManagedSettingRestorationSafety.plan(
            for: future,
            target: .activation
        ) == nil)
        #expect(ManagedSettingRestorationSafety.plan(
            for: corruptFallback,
            target: .restoration
        ) == nil)
    }

    @Test func invalidOrUnrestorableSnapshotsProduceNoMutationPlan() {
        let records = [
            sentinel(lowPowerModeKey: "lowpowermode"),
            sentinel(lowPowerMode: ["Battery Power": 0]),
            sentinel(lowPowerModeKey: "lowpowermode", lowPowerMode: [:]),
            sentinel(
                lowPowerModeKey: "futurepowermode",
                lowPowerMode: ["Battery Power": 0]
            ),
            sentinel(
                lowPowerModeKey: "powermode",
                lowPowerMode: ["Future Power": 0]
            ),
            sentinel(tcpKeepAlive: [:]),
            sentinel(tcpKeepAlive: ["Future Power": 1]),
        ]

        for record in records {
            #expect(ManagedSettingRestorationSafety.plan(
                for: record,
                target: .activation
            ) == nil)
            #expect(ManagedSettingRestorationSafety.plan(
                for: record,
                target: .restoration
            ) == nil)
        }
    }

    @Test func plansAreDeterministicGroupedAndLimitedToCapturedScopes() throws {
        let record = sentinel(
            lowPowerModeKey: "powermode",
            lowPowerMode: ["AC Power": 2, "Battery Power": 0],
            tcpKeepAlive: ["UPS Power": 0, "AC Power": 1]
        )

        let activation = try #require(ManagedSettingRestorationSafety.plan(
            for: record,
            target: .activation
        ))
        #expect(activation == [
            .init(scope: .battery, settings: [
                .init(key: "powermode", value: 1),
            ]),
            .init(scope: .ac, settings: [
                .init(key: "powermode", value: 1),
                .init(key: "tcpkeepalive", value: 1),
            ]),
            .init(scope: .ups, settings: [
                .init(key: "tcpkeepalive", value: 1),
            ]),
        ])

        let restoration = try #require(ManagedSettingRestorationSafety.plan(
            for: record,
            target: .restoration
        ))
        #expect(restoration == [
            .init(scope: .battery, settings: [
                .init(key: "powermode", value: 0),
            ]),
            .init(scope: .ac, settings: [
                .init(key: "powermode", value: 2),
                .init(key: "tcpkeepalive", value: 1),
            ]),
            .init(scope: .ups, settings: [
                .init(key: "tcpkeepalive", value: 0),
            ]),
        ])
        #expect(restoration.count
            <= ManagedSettingRestorationSafety.maximumScopeCommandCount)
        #expect(ManagedSettingRestorationSafety.Scope.allCases.map(\.pmsetFlag)
            == ["-b", "-c", "-u"])
    }

    @Test func restorationRequiresFreshExactReadableProofForEveryPrior() throws {
        let record = sentinel(
            lowPowerModeKey: "lowpowermode",
            lowPowerMode: ["Battery Power": 0, "AC Power": 1],
            tcpKeepAlive: ["AC Power": 0]
        )
        let plan = try #require(ManagedSettingRestorationSafety.plan(
            for: record,
            target: .restoration
        ))
        #expect(!plan.isEmpty)
        let exact = """
        Battery Power:
         lowpowermode 0
        AC Power:
         lowpowermode 1
         tcpkeepalive 0
        """

        #expect(ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: exact
        ))
        #expect(ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: exact + "\nFuture Power:\n tcpkeepalive 1\n"
        ))
        #expect(!ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: nil
        ))
        #expect(!ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: exact.replacingOccurrences(of: "tcpkeepalive 0", with: "")
        ))
        #expect(!ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: exact.replacingOccurrences(of: "lowpowermode 1", with: "lowpowermode 2")
        ))
        #expect(!ManagedSettingRestorationSafety.isRestorationProven(
            for: record,
            fromCustom: exact.replacingOccurrences(of: "tcpkeepalive 0", with: "tcpkeepalive off")
        ))
        #expect(!ManagedSettingRestorationSafety.isRestorationProven(
            for: sentinel(tcpKeepAlive: [:]),
            fromCustom: exact
        ))
    }

    @Test func activationRequiresFreshExactReadableProofForEveryTarget() throws {
        let record = sentinel(
            lowPowerModeKey: "lowpowermode",
            lowPowerMode: ["Battery Power": 0, "AC Power": 0],
            tcpKeepAlive: ["AC Power": 0]
        )
        let exact = """
        Battery Power:
         lowpowermode 1
        AC Power:
         lowpowermode 1
         tcpkeepalive 1
        """

        #expect(ManagedSettingRestorationSafety.isProven(
            for: record,
            target: .activation,
            fromCustom: exact
        ))
        for invalid in [
            nil,
            exact.replacingOccurrences(of: "tcpkeepalive 1", with: ""),
            exact.replacingOccurrences(
                of: "lowpowermode 1",
                with: "lowpowermode 0",
                options: [],
                range: exact.range(of: "lowpowermode 1")
            ),
            exact.replacingOccurrences(of: "tcpkeepalive 1", with: "tcpkeepalive on"),
        ] as [String?] {
            #expect(!ManagedSettingRestorationSafety.isProven(
                for: record,
                target: .activation,
                fromCustom: invalid
            ))
        }
    }

    @Test func captureAndProofRejectMalformedOrAmbiguousCustomOutput() {
        let record = sentinel(
            lowPowerModeKey: "lowpowermode",
            lowPowerMode: ["Battery Power": 0]
        )
        let untrustworthy = [
            "Battery Power:\n lowpowermode 0\n orphan",
            "Battery Power:\n lowpowermode 1\n lowpowermode 0",
            "Battery Power:\n lowpowermode 1\nBattery Power:\n lowpowermode 0",
        ]

        for text in untrustworthy {
            #expect(ManagedSettingRestorationSafety.capturedPriors(
                for: "lowpowermode",
                fromCustom: text
            ) == nil)
            #expect(!ManagedSettingRestorationSafety.isProven(
                for: record,
                target: .restoration,
                fromCustom: text
            ))
        }
    }

    @Test func noManagedPriorsNeedNoCustomReadback() throws {
        let plan = try #require(ManagedSettingRestorationSafety.plan(
            for: sentinel(),
            target: .restoration
        ))
        #expect(plan.isEmpty)
        #expect(ManagedSettingRestorationSafety.isRestorationProven(
            for: sentinel(),
            fromCustom: nil
        ))
        #expect(ManagedSettingRestorationSafety.isProven(
            for: sentinel(),
            target: .activation,
            fromCustom: nil
        ))
    }

    @Test func helperRestoresAndProvesManagedValuesBeforeDeletingSentinel() throws {
        let helper = try repositoryFile("Helper/HelperDaemon.swift")
        let pmset = try repositoryFile("Helper/PMSet.swift")
        let arm = try section(
            of: helper,
            from: "fileprivate func handleArm(",
            through: "private func rejectPreparedArm("
        )
        let restore = try section(
            of: helper,
            from: "private func performRestore(",
            through: "private func scheduleRestoreRetry()"
        )
        let recovery = try section(
            of: helper,
            from: "private func recoveryPass(storageFailure: Error?)",
            through: "private func installSignalHandlers()"
        )
        let applyImplementation = try section(
            of: pmset,
            from: "static func apply(",
            through: "// MARK: - Scheduled wake"
        )

        #expect(!pmset.contains("setEverywhere"))
        #expect(!pmset.contains("static func restore(key:"))
        #expect(pmset.contains("static func apply("))
        #expect(applyImplementation.contains("scopedMutation.scope.pmsetFlag"))
        #expect(applyImplementation.contains("try run(arguments)"))
        #expect(!applyImplementation.contains("catch"))
        #expect(!applyImplementation.contains("try?"))
        #expect(arm.contains("ManagedSettingRestorationSafety.capturedPriors"))
        #expect(arm.contains("let managedActivationPlan"))
        #expect(arm.contains("try PMSet.apply(managedActivationPlan)"))
        #expect(arm.contains(
            "HelperSupervisionTiming.maximumArmTransactionCommandCount"
        ))
        #expect(!arm.contains("try PMSet.run([\"-a\""))
        #expect(recovery.contains("let fallback = OverrideSentinel("))
        #expect(recovery.contains("version: 0"))
        #expect(!recovery.contains(
            "version: OverrideSentinel.currentVersion"
        ))
        let corruptVersion = try #require(recovery.range(of: "version: 0"))
        let corruptRestore = try #require(recovery.range(
            of: "performRestore(fallback, reason: reason)"
        ))
        #expect(corruptVersion.lowerBound < corruptRestore.lowerBound)

        let activationPlan = try #require(arm.range(
            of: "let managedActivationPlan"
        ))
        let sentinelWrite = try #require(arm.range(of: "try writeSentinel(record)"))
        #expect(activationPlan.lowerBound < sentinelWrite.lowerBound)

        let activationApply = try #require(arm.range(
            of: "try PMSet.apply(managedActivationPlan)"
        ))
        let afterEnableProof = arm[try #require(arm.range(
            of: "let armReadback = PMSet.readSleepDisabled()"
        )).upperBound..<activationApply.lowerBound]
        let freshPriorReadback = try #require(afterEnableProof.range(
            of: "try PMSet.readCustom()"
        ))
        let freshPriorProof = try #require(afterEnableProof.range(
            of: "target: .restoration"
        ))
        #expect(freshPriorReadback.lowerBound < freshPriorProof.lowerBound)
        #expect(afterEnableProof.contains(
            "captured managed settings changed while preparing to arm"
        ))
        let afterActivationApply = arm[activationApply.upperBound...]
        let activationReadback = try #require(afterActivationApply.range(
            of: "try PMSet.readCustom()"
        ))
        let activationProof = try #require(afterActivationApply.range(
            of: "target: .activation"
        ))
        let successReply = try #require(arm.range(
            of: "reply(IPCCoding.encode(result))"
        ))
        #expect(activationApply.lowerBound < activationReadback.lowerBound)
        #expect(activationReadback.lowerBound < activationProof.lowerBound)
        #expect(activationProof.lowerBound < successReply.lowerBound)
        #expect(!arm.contains("Best-effort extras"))

        let plan = try #require(restore.range(of: "let managedRestorationPlan"))
        let apply = try #require(restore.range(
            of: "try PMSet.apply(managedRestorationPlan)"
        ))
        let readback = try #require(restore.range(of: "try PMSet.readCustom()"))
        let proof = try #require(restore.range(
            of: "ManagedSettingRestorationSafety.isRestorationProven"
        ))
        let removal = try #require(restore.range(of: "try removeSentinelFile()"))
        #expect(plan.lowerBound < apply.lowerBound)
        #expect(apply.lowerBound < readback.lowerBound)
        #expect(readback.lowerBound < proof.lowerBound)
        #expect(proof.lowerBound < removal.lowerBound)
        #expect(restore.contains("for: record"))
        #expect(restore.contains("parkRestore("))
        #expect(restore.contains("restorePending = record"))
        #expect(!restore.contains("Extras are best-effort"))
    }

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
}
