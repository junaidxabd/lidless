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
        // Low Power Mode and tcpkeepalive are the only two blocking commands
        // permitted after arm proof. Connection invalidation and the watchdog
        // must still get queue time before the minimum TTL expires.
        #expect(HelperSupervisionTiming.isWithinWatchdogBudget(
            commandCount: 2,
            watchdogTTL: HelperArmOptions.watchdogTTLRange.lowerBound
        ))
    }

    @Test func budgetRejectsWorkThatCanConsumeTheWholeTTL() {
        #expect(!HelperSupervisionTiming.isWithinWatchdogBudget(
            commandCount: 4,
            watchdogTTL: HelperArmOptions.watchdogTTLRange.lowerBound
        ))
    }
}
