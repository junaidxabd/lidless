import Foundation
import Security

/// Builds the privileged helper's peer requirement from the dynamically
/// validated identity of the running process. An unsigned or invalid helper
/// has no trustworthy team anchor and therefore fails closed.
public enum XPCPeerPolicy {
    public static func validatedRequirementForCurrentProcess(
        appBundleID: String,
        helperBundleID: String
    ) -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess,
              let code
        else { return nil }

        return validatedRequirement(
            appBundleID: appBundleID,
            helperBundleID: helperBundleID,
            validateRequirement: { requirementText in
                guard let requirement = parseRequirement(requirementText) else {
                    return false
                }
                return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
            },
            copyTeamIdentifier: {
                var staticCode: SecStaticCode?
                guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
                      let staticCode
                else { return nil }

                var info: CFDictionary?
                guard SecCodeCopySigningInformation(
                    staticCode,
                    SecCSFlags(rawValue: kSecCSSigningInformation),
                    &info
                ) == errSecSuccess,
                let dict = info as? [String: Any]
                else { return nil }
                return dict[kSecCodeInfoTeamIdentifier as String] as? String
            }
        )
    }

    /// Testable ordering seam for the signing API pipeline. Signing
    /// information can contain invalid or partial data, so the helper's base
    /// identity must validate before extracting a candidate team. That exact
    /// candidate is then bound into a second validity check before it can
    /// become the peer trust anchor.
    static func validatedRequirement(
        appBundleID: String,
        helperBundleID: String,
        validateRequirement: (String) -> Bool,
        copyTeamIdentifier: () -> String?
    ) -> String? {
        guard isValidBundleID(appBundleID),
              let baseRequirement = helperRequirement(
                helperBundleID: helperBundleID,
                teamIdentifier: nil
              ),
              validateRequirement(baseRequirement),
              let teamIdentifier = copyTeamIdentifier(),
              let boundRequirement = helperRequirement(
                helperBundleID: helperBundleID,
                teamIdentifier: teamIdentifier
              ),
              validateRequirement(boundRequirement)
        else { return nil }

        return requirement(
            appBundleID: appBundleID,
            teamIdentifier: teamIdentifier
        )
    }

    /// Internal syntax builder. Production callers can only obtain a
    /// requirement through `validatedRequirementForCurrentProcess` above.
    static func requirement(
        appBundleID: String,
        teamIdentifier: String?
    ) -> String? {
        guard let teamIdentifier,
              isValidBundleID(appBundleID),
              !teamIdentifier.isEmpty,
              teamIdentifier.rangeOfCharacter(from: teamIDCharacters.inverted) == nil
        else { return nil }

        return "anchor apple generic and identifier \"\(appBundleID)\" and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }

    private static func helperRequirement(
        helperBundleID: String,
        teamIdentifier: String?
    ) -> String? {
        guard isValidBundleID(helperBundleID) else { return nil }
        var text = "anchor apple generic and identifier \"\(helperBundleID)\""
        if let teamIdentifier {
            guard !teamIdentifier.isEmpty,
                  teamIdentifier.rangeOfCharacter(from: teamIDCharacters.inverted) == nil
            else { return nil }
            text += " and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
        }
        return text
    }

    private static func parseRequirement(_ text: String) -> SecRequirement? {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(
            text as CFString,
            [],
            &requirement
        ) == errSecSuccess
        else { return nil }
        return requirement
    }

    private static func isValidBundleID(_ value: String) -> Bool {
        !value.isEmpty
            && value.rangeOfCharacter(from: bundleIDCharacters.inverted) == nil
    }

    private static let bundleIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
    )
    private static let teamIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )
}
