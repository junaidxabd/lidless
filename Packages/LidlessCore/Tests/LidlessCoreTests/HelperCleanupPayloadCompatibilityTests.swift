import Foundation
import Testing
@testable import LidlessCore

@Suite("Helper cleanup refusal payload compatibility")
struct HelperCleanupPayloadCompatibilityTests {
    private let status = HelperStatus(
        helperVersion: LidlessIDs.helperVersion,
        helperSafetyRevision: LidlessIDs.helperSafetyRevision,
        armed: false,
        sleepDisabled: false,
        sleepStateVerified: true,
        restorePending: false
    )

    @Test func refusalPreparationRoundTripsWithoutAuthorization() throws {
        let preparation = HelperCleanupPreparation(
            ok: false,
            error: "automatic helper cleanup is disabled; a reviewed removal procedure is required",
            status: status
        )

        let decoded = try #require(IPCCoding.decode(
            HelperCleanupPreparation.self,
            from: IPCCoding.encode(preparation)
        ))

        #expect(decoded == preparation)
        #expect(!decoded.ok)
        #expect(decoded.authorization == nil)
        #expect(decoded.status == status)
    }

    @Test func legacyAuthorizationFieldStillRoundTripsAsWireData() throws {
        let process = UUID(uuidString: "3DF851F2-50F0-4B1A-84D9-B3A5582844DA")!
        let preparation = HelperCleanupPreparation(
            ok: false,
            authorization: HelperCleanupAuthorization(helperInstanceID: process),
            status: status
        )

        let decoded = try #require(IPCCoding.decode(
            HelperCleanupPreparation.self,
            from: IPCCoding.encode(preparation)
        ))

        #expect(decoded.authorization?.helperInstanceID == process)
    }

    @Test func malformedLegacyAuthorizationFailsToDecode() {
        let malformed = Data(#"{"helperInstanceID":17}"#.utf8)

        #expect(IPCCoding.decode(
            HelperCleanupAuthorization.self,
            from: malformed
        ) == nil)
    }
}
