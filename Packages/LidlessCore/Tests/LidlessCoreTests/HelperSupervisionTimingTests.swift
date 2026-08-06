import Testing
import LidlessCore

@Suite("Helper supervision timing")
struct HelperSupervisionTimingTests {
    @Test func safetyCriticalRecoveryFitsInsideMinimumWatchdogTTL() {
        // A timed-out enable followed by its fail-safe restore is the longest
        // sequence allowed before in-memory supervision can take over.
        #expect(HelperSupervisionTiming.maximumBlockingInterval(commandCount: 2)
            < HelperArmOptions.watchdogTTLRange.lowerBound)
    }

    @Test func postProofOptionalMutationsLeaveWatchdogMargin() {
        // Each captured power-source scope is one grouped command. Connection
        // invalidation and the watchdog must still get queue time before the
        // minimum TTL expires.
        #expect(ManagedSettingRestorationSafety.maximumScopeCommandCount == 3)
        #expect(HelperSupervisionTiming.isWithinWatchdogBudget(
            commandCount: ManagedSettingRestorationSafety.maximumScopeCommandCount,
            watchdogTTL: HelperArmOptions.watchdogTTLRange.lowerBound
        ))
    }

    @Test func executingManagedRestoreHasABoundedChildCommandBudget() {
        // One disablesleep command, at most three scoped managed commands,
        // then one `pmset -g custom` proof read. Once restore begins executing,
        // its own child waits fit inside 25 seconds. Earlier queue occupancy,
        // filesystem work, and IOKit can still outlive the app's local timer.
        let childCommandCount = 1
            + ManagedSettingRestorationSafety.maximumScopeCommandCount
            + 1
        #expect(HelperSupervisionTiming.maximumBlockingInterval(
            commandCount: childCommandCount
        ) < HelperXPCRequestSafety.replyTimeout)
    }

    @Test func budgetRejectsWorkThatCanConsumeTheWholeTTL() {
        #expect(!HelperSupervisionTiming.isWithinWatchdogBudget(
            commandCount: 4,
            watchdogTTL: HelperArmOptions.watchdogTTLRange.lowerBound
        ))
    }
}
