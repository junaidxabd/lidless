import Testing
@testable import LidlessCore

@Suite("XPCPeerPolicy")
struct XPCPeerPolicyTests {
    @Test func unsignedHelperFailsClosed() {
        #expect(XPCPeerPolicy.validatedRequirementForCurrentProcess(
            appBundleID: LidlessIDs.appBundleID,
            helperBundleID: LidlessIDs.helperLabel
        ) == nil)
    }

    @Test func validationPrecedesTeamExtractionAndCandidateBinding() {
        var events: [String] = []

        let result = XPCPeerPolicy.validatedRequirement(
            appBundleID: "com.example.app",
            helperBundleID: "com.example.helper",
            validateRequirement: { requirement in
                events.append("validate:\(requirement)")
                return true
            },
            copyTeamIdentifier: {
                events.append("copy-team")
                return "ABCDE12345"
            }
        )

        #expect(result == "anchor apple generic and identifier \"com.example.app\" and certificate leaf[subject.OU] = \"ABCDE12345\"")
        #expect(events == [
            "validate:anchor apple generic and identifier \"com.example.helper\"",
            "copy-team",
            "validate:anchor apple generic and identifier \"com.example.helper\" and certificate leaf[subject.OU] = \"ABCDE12345\"",
        ])
    }

    @Test func baseValidationFailurePreventsTeamExtraction() {
        var events: [String] = []

        let result = XPCPeerPolicy.validatedRequirement(
            appBundleID: "com.example.app",
            helperBundleID: "com.example.helper",
            validateRequirement: { requirement in
                events.append("validate:\(requirement)")
                return false
            },
            copyTeamIdentifier: {
                events.append("copy-attacker-team")
                return "ATTACKER01"
            }
        )

        #expect(result == nil)
        #expect(events == [
            "validate:anchor apple generic and identifier \"com.example.helper\"",
        ])
    }

    @Test func candidateBoundValidationFailureFailsClosed() {
        var events: [String] = []

        let result = XPCPeerPolicy.validatedRequirement(
            appBundleID: "com.example.app",
            helperBundleID: "com.example.helper",
            validateRequirement: { requirement in
                events.append("validate:\(requirement)")
                return events.count == 1
            },
            copyTeamIdentifier: {
                events.append("copy-team")
                return "ATTACKER01"
            }
        )

        #expect(result == nil)
        #expect(events == [
            "validate:anchor apple generic and identifier \"com.example.helper\"",
            "copy-team",
            "validate:anchor apple generic and identifier \"com.example.helper\" and certificate leaf[subject.OU] = \"ATTACKER01\"",
        ])
    }

    @Test func missingOrInvalidTeamFailsBeforeBoundValidation() {
        for teamIdentifier in [nil, "TEAM\" or true"] as [String?] {
            var validationCount = 0

            let result = XPCPeerPolicy.validatedRequirement(
                appBundleID: "com.example.app",
                helperBundleID: "com.example.helper",
                validateRequirement: { _ in
                    validationCount += 1
                    return true
                },
                copyTeamIdentifier: { teamIdentifier }
            )

            #expect(result == nil)
            #expect(validationCount == 1)
        }
    }

    @Test func signedHelperPinsBothAppAndTeam() {
        #expect(XPCPeerPolicy.requirement(
            appBundleID: "com.example.app",
            teamIdentifier: "ABCDE12345"
        ) == "anchor apple generic and identifier \"com.example.app\" and certificate leaf[subject.OU] = \"ABCDE12345\"")
    }

    @Test func invalidExpectedHelperIdentityFailsClosed() {
        #expect(XPCPeerPolicy.validatedRequirementForCurrentProcess(
            appBundleID: "com.example.app",
            helperBundleID: "com.example.helper\" or true"
        ) == nil)
    }

    @Test func emptySigningInputsFailClosed() {
        #expect(XPCPeerPolicy.requirement(appBundleID: "", teamIdentifier: "ABCDE12345") == nil)
        #expect(XPCPeerPolicy.requirement(appBundleID: "com.example.app", teamIdentifier: "") == nil)
        #expect(XPCPeerPolicy.requirement(appBundleID: "com.example.app\" or true", teamIdentifier: "ABCDE12345") == nil)
        #expect(XPCPeerPolicy.requirement(appBundleID: "com.example.app", teamIdentifier: "TEAM\" or true") == nil)
    }
}
