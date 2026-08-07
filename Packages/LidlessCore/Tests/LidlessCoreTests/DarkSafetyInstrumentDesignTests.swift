import Foundation
import Testing

@Suite("Dark safety instrument design contracts")
struct DarkSafetyInstrumentDesignTests {
    @Test func themeUsesQuietFixedDarkSemanticTokens() throws {
        let theme = try repositoryFile("App/Sources/Support/Theme.swift")

        for requiredToken in [
            "static let panelWidth: CGFloat = 380",
            "static let canvas",
            "static let surface",
            "static let surfaceElevated",
            "static let separator",
            "static let textPrimary",
            "static let textSecondary",
            "static let textTertiary",
            "static let verifiedNormal",
            "static let verifiedActive",
            "static let caution",
            "static let critical",
        ] {
            #expect(theme.contains(requiredToken))
        }

        for forbiddenImplementation in [
            "TimelineView",
            "LinearGradient(",
            "AngularGradient(",
            "RadialGradient(",
            ".blur(",
            ".shadow(",
            "auroraColors",
            "auroraStrength",
            "design: .rounded",
            ".fontDesign(.rounded)",
        ] {
            #expect(!theme.contains(forbiddenImplementation))
        }

        let lowercased = theme.lowercased()
        #expect(!lowercased.contains("eye motif"))
        #expect(!lowercased.contains("happy mac"))
        #expect(!lowercased.contains("mascot"))
        #expect(!theme.contains("AuroraBackground"))
        #expect(!theme.contains("GlowText"))
        #expect(!theme.contains("func glow"))
        #expect(!theme.contains("Gradient"))
    }

    @Test func sharedComponentsUseProofFirstSemanticStateStyling() throws {
        let components = try repositoryFile("App/Sources/UI/Components.swift")

        for requiredCopy in [
            "VERIFIED NORMAL",
            "VERIFYING",
            "KEEP-AWAKE ON",
            "RESTORING",
            "OUTSIDE OVERRIDE",
            "UNVERIFIED",
        ] {
            #expect(components.contains(requiredCopy))
        }

        #expect(components.contains("Theme.verifiedNormal"))
        #expect(components.contains("Theme.verifiedActive"))
        #expect(components.contains("Theme.caution"))
        #expect(components.contains("Theme.critical"))
        #expect(!components.contains("Theme.armedGradient"))
        #expect(!components.contains(".glow("))
        #expect(!components.contains("design: .rounded"))
    }

    @Test func primaryActionMapsEveryCanonicalPresentationToOneTruthfulAction() throws {
        let components = try repositoryFile("App/Sources/UI/Components.swift")

        #expect(components.contains("enum PrimaryActionSemantic"))
        #expect(components.contains("case keepAwake"))
        #expect(components.contains("case restoreNormalSleep"))
        #expect(components.contains("case checkAgain"))
        #expect(components.contains("case progress"))
        #expect(components.contains("case .verifiedNormal: .keepAwake"))
        #expect(components.contains("case .verifiedArmed, .outsideOverride: .restoreNormalSleep"))
        #expect(components.contains("case .unknown: .checkAgain"))
        #expect(components.contains("case .verifyingArm, .restoring: .progress"))
        #expect(components.contains("Button(action: performAction)"))
        #expect(components.contains(".disabled(!actionAvailable || semantic == .progress)"))
    }

    @Test func sharedMotionAndControlsRespectNativeAccessibility() throws {
        let components = try repositoryFile("App/Sources/UI/Components.swift")

        #expect(components.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(components.contains(".animation(reduceMotion ? nil"))
        #expect(components.contains(".buttonStyle(.bordered)"))
        #expect(components.contains(".accessibilityLabel(accessibilityLabel)"))
        #expect(!components.contains(".onHover"))
        #expect(!components.contains(".scaleEffect"))
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
}
