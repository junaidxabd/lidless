import Testing
import LidlessCore

@Suite("SleepOverrideSafety")
struct SleepOverrideSafetyTests {
    @Test func verifiedSleepStateProtocolIsVersionFive() {
        #expect(LidlessIDs.helperVersion == 5)
    }

    @Test func unknownReadbackNeverVerifiesAMutation() {
        // Break caught: a missing IOKit read must not be treated as proof that
        // either enabling or restoring the system-wide override succeeded.
        #expect(!SleepOverrideSafety.isVerified(expected: true, observed: nil))
        #expect(!SleepOverrideSafety.isVerified(expected: false, observed: nil))
    }

    @Test func onlyAnExactReadbackVerifiesAMutation() {
        #expect(SleepOverrideSafety.isVerified(expected: true, observed: true))
        #expect(SleepOverrideSafety.isVerified(expected: false, observed: false))
        #expect(!SleepOverrideSafety.isVerified(expected: true, observed: false))
        #expect(!SleepOverrideSafety.isVerified(expected: false, observed: true))
    }

    @Test func freshArmRequiresAReadableInactivePriorState() {
        // Break caught: Lidless must not take ownership of an override that is
        // already active, or invent an inactive prior when IOKit is unreadable.
        #expect(SleepOverrideSafety.preflight(observed: false) == .safeToArm)
        #expect(SleepOverrideSafety.preflight(observed: true) == .externalOverrideActive)
        #expect(SleepOverrideSafety.preflight(observed: nil) == .stateUnverified)
    }

    @Test func legacySentinelCannotRedefineNormalSleep() {
        // v4 could record an already-active external override as the prior.
        // v5 never lets that legacy value survive a recovery as "normal".
        #expect(!SleepOverrideSafety.restoreTarget(recordedPrior: false))
        #expect(!SleepOverrideSafety.restoreTarget(recordedPrior: true))
    }

    @Test func appAcceptsOnlyAProvenArm() {
        let proven = HelperReply(
            ok: true,
            status: HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: true,
                sleepDisabled: true,
                sleepStateVerified: true,
                restorePending: false
            )
        )
        #expect(SleepOverrideSafety.isArmProven(proven))

        let unproven = [
            HelperReply(
                ok: false,
                status: proven.status
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: false,
                    sleepDisabled: true,
                    sleepStateVerified: true,
                    restorePending: false
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: true,
                    sleepDisabled: false,
                    sleepStateVerified: true,
                    restorePending: false
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: true,
                    sleepDisabled: true,
                    sleepStateVerified: false,
                    restorePending: false
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: true,
                    sleepDisabled: true,
                    sleepStateVerified: true,
                    restorePending: true
                )
            )
        ]

        for reply in unproven {
            #expect(!SleepOverrideSafety.isArmProven(reply))
        }
    }

    @Test func appFinalizesOnlyAProvenRestore() {
        let proven = HelperReply(
            ok: true,
            status: HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: false
            )
        )
        #expect(SleepOverrideSafety.isRestoreProven(proven))
    }

    @Test func appKeepsRecoveryVisibleForEveryUnprovenRestore() {
        // Break caught: the app must not end the session or announce success
        // when the helper failed, the readback is unknown/still on, or a retry
        // remains pending.
        let cases = [
            HelperReply(
                ok: false,
                error: "restore failed; helper is retrying",
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: false,
                    sleepDisabled: true,
                    sleepStateVerified: true,
                    restorePending: true
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: false,
                    sleepDisabled: false,
                    sleepStateVerified: false,
                    restorePending: false
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: false,
                    sleepDisabled: true,
                    sleepStateVerified: true,
                    restorePending: false
                )
            ),
            HelperReply(
                ok: true,
                status: HelperStatus(
                    helperVersion: LidlessIDs.helperVersion,
                    armed: false,
                    sleepDisabled: false,
                    sleepStateVerified: true,
                    restorePending: true
                )
            )
        ]

        for reply in cases {
            #expect(!SleepOverrideSafety.isRestoreProven(reply))
        }
    }

    @Test func statusPollingRequiresACompleteVerifiedRestore() {
        let proven = HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            armed: false,
            sleepDisabled: false,
            sleepStateVerified: true,
            restorePending: false
        )
        #expect(SleepOverrideSafety.isRestoreProven(proven))

        let unproven = [
            HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: true,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: false
            ),
            HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: true,
                sleepStateVerified: true,
                restorePending: false
            ),
            HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: false,
                restorePending: false
            ),
            HelperStatus(
                helperVersion: LidlessIDs.helperVersion,
                armed: false,
                sleepDisabled: false,
                sleepStateVerified: true,
                restorePending: true
            )
        ]

        for status in unproven {
            #expect(!SleepOverrideSafety.isRestoreProven(status))
        }
    }
}
