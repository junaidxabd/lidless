import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper cleanup handshake")
struct HelperCleanupHandshakeTests {
    @Test func onlyTheIssuingHelperProcessAuthorizesCleanup() {
        let issuingProcess = UUID(uuidString: "11A56991-0D5B-45A8-B91D-18AC35440D40")!
        let replacementProcess = UUID(uuidString: "C83C705F-7FD5-4FB8-A643-501269B55B66")!
        let authorization = HelperCleanupAuthorization(
            helperInstanceID: issuingProcess
        )

        #expect(HelperCleanupHandshakeSafety.authorizes(
            authorization,
            issuedBy: issuingProcess
        ))
        #expect(!HelperCleanupHandshakeSafety.authorizes(
            authorization,
            issuedBy: replacementProcess
        ))
    }

    @Test func authorizationAndPreparationRoundTripWithoutChangingIdentity() throws {
        let process = UUID(uuidString: "3DF851F2-50F0-4B1A-84D9-B3A5582844DA")!
        let status = HelperStatus(
            helperVersion: LidlessIDs.helperVersion,
            helperSafetyRevision: LidlessIDs.helperSafetyRevision,
            armed: false,
            sleepDisabled: false,
            sleepStateVerified: true,
            restorePending: false
        )
        let preparation = HelperCleanupPreparation(
            ok: true,
            authorization: HelperCleanupAuthorization(helperInstanceID: process),
            status: status
        )

        let encoded = IPCCoding.encode(preparation)
        let decoded = try #require(IPCCoding.decode(
            HelperCleanupPreparation.self,
            from: encoded
        ))

        #expect(decoded == preparation)
        #expect(decoded.authorization?.helperInstanceID == process)
        #expect(SleepOverrideSafety.isCurrentHelper(decoded.status))
    }

    @Test func malformedAuthorizationCannotBecomeAValidCommit() {
        let process = UUID(uuidString: "D6ABEC0D-8EB5-48EC-AE43-C55A89E6CC60")!
        let replacement = UUID(uuidString: "2BB17E0F-D680-405A-9EB8-6CEEE402DC0B")!
        let malformed = Data(#"{"helperInstanceID":17}"#.utf8)

        #expect(IPCCoding.decode(
            HelperCleanupAuthorization.self,
            from: malformed
        ) == nil)
        #expect(!HelperCleanupHandshakeSafety.authorizes(
            HelperCleanupAuthorization(helperInstanceID: replacement),
            issuedBy: process
        ))
    }
}
