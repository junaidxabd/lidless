import Testing
@testable import LidlessCore

@Suite("Helper session ownership safety")
struct HelperSessionOwnershipSafetyTests {
    @Test func onlyAFreshArmCanEstablishSessionOwnership() {
        #expect(HelperSessionOwnershipSafety.armDisposition(
            hasActiveSession: false
        ) == .beginFreshSession)
        #expect(HelperSessionOwnershipSafety.armDisposition(
            hasActiveSession: true
        ) == .rejectActiveSession)
    }

    @Test func onlyTheExactOwnerMayRenewAnActiveSession() {
        #expect(HelperSessionOwnershipSafety.heartbeatDisposition(
            hasActiveSession: true,
            owner: 41,
            requester: 41
        ) == .renew)
        #expect(HelperSessionOwnershipSafety.heartbeatDisposition(
            hasActiveSession: true,
            owner: 41,
            requester: 42
        ) == .rejectNonOwner)
    }

    @Test func missingOwnershipCannotRenewAnActiveSession() {
        #expect(HelperSessionOwnershipSafety.heartbeatDisposition(
            hasActiveSession: true,
            owner: Optional<Int>.none,
            requester: 41
        ) == .rejectNonOwner)
    }

    @Test func anOwnerIdentityCannotRenewAfterTheSessionEnds() {
        #expect(HelperSessionOwnershipSafety.heartbeatDisposition(
            hasActiveSession: false,
            owner: 41,
            requester: 41
        ) == .rejectNoSession)
    }
}
