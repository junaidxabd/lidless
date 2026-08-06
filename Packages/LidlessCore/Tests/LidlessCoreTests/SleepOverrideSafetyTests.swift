import Testing
import LidlessCore

@Suite("SleepOverrideSafety")
struct SleepOverrideSafetyTests {
    @Test func verifiedSleepStateProtocolIsVersionSix() {
        #expect(LidlessIDs.helperVersion == 6)
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
                    helperVersion: LidlessIDs.helperVersion - 1,
                    armed: true,
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

@Suite("Helper storage safety")
struct HelperStorageSafetyTests {
    private func metadata(
        kind: HelperStorageSafety.ObjectKind,
        ownerUID: UInt32 = 0,
        ownerGID: UInt32 = 0,
        permissions: UInt32,
        linkCount: UInt64 = 1,
        hasExtendedACL: Bool = false
    ) -> HelperStorageSafety.Metadata {
        HelperStorageSafety.Metadata(
            kind: kind,
            ownerUID: ownerUID,
            ownerGID: ownerGID,
            permissions: permissions,
            linkCount: linkCount,
            hasExtendedACL: hasExtendedACL
        )
    }

    @Test func workDirectoryRequiresExactRootOwnedNonACLDirectory() {
        let proven = metadata(
            kind: .directory,
            permissions: 0o755,
            linkCount: 2
        )
        #expect(HelperStorageSafety.isSecureStorageDirectory(proven))
        #expect(HelperStorageSafety.isSecureWorkDirectory(proven))

        let rejected = [
            metadata(kind: .regularFile, permissions: 0o755),
            metadata(kind: .other, permissions: 0o755),
            metadata(kind: .directory, ownerUID: 501, permissions: 0o755),
            metadata(kind: .directory, ownerGID: 20, permissions: 0o755),
            metadata(kind: .directory, permissions: 0o777),
            metadata(kind: .directory, permissions: 0o750),
            metadata(kind: .directory, permissions: 0o1755),
            metadata(
                kind: .directory,
                permissions: 0o755,
                hasExtendedACL: true
            )
        ]

        for candidate in rejected {
            #expect(!HelperStorageSafety.isSecureStorageDirectory(candidate))
            #expect(!HelperStorageSafety.isSecureWorkDirectory(candidate))
        }
    }

    @Test func sentinelRequiresExactRootOwnedSingleLinkOwnerOnlyFile() {
        let proven = metadata(kind: .regularFile, permissions: 0o600)
        #expect(HelperStorageSafety.isSecureSentinel(proven))

        let rejected = [
            metadata(kind: .directory, permissions: 0o600),
            metadata(kind: .other, permissions: 0o600),
            metadata(kind: .regularFile, ownerUID: 501, permissions: 0o600),
            metadata(kind: .regularFile, ownerGID: 20, permissions: 0o600),
            metadata(kind: .regularFile, permissions: 0o644),
            metadata(kind: .regularFile, permissions: 0o400),
            metadata(kind: .regularFile, permissions: 0o4600),
            metadata(kind: .regularFile, permissions: 0o600, linkCount: 2),
            metadata(
                kind: .regularFile,
                permissions: 0o600,
                hasExtendedACL: true
            )
        ]

        for candidate in rejected {
            #expect(!HelperStorageSafety.isSecureSentinel(candidate))
        }
    }

    @Test func sentinelContentsAreTrustedOnlyAcrossBothMetadataProofs() {
        let directory = metadata(
            kind: .directory,
            permissions: 0o755,
            linkCount: 2
        )
        let sentinel = metadata(kind: .regularFile, permissions: 0o600)

        #expect(HelperStorageSafety.isTrustedSentinel(
            workDirectory: directory,
            sentinel: sentinel
        ))
        #expect(!HelperStorageSafety.isTrustedSentinel(
            workDirectory: metadata(kind: .directory, permissions: 0o777),
            sentinel: sentinel
        ))
        #expect(!HelperStorageSafety.isTrustedSentinel(
            workDirectory: directory,
            sentinel: metadata(kind: .regularFile, permissions: 0o644)
        ))
    }
}
