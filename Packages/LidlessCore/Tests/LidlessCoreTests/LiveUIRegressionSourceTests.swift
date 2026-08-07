import Foundation
import Testing

@Suite("Live UI regression contracts")
struct LiveUIRegressionSourceTests {
    @Test func onboardingFitsTheMinimumWindowAndEvidenceUsesTheSameSize() throws {
        let onboarding = try repositoryFile(
            "App/Sources/UI/Onboarding/OnboardingView.swift"
        )
        let renderer = try repositoryFile(
            "App/Sources/Services/ScreenshotRenderer.swift"
        )

        #expect(onboarding.contains("enum OnboardingLayout"))
        #expect(onboarding.contains("static let width: CGFloat = 600"))
        #expect(onboarding.contains("static let height: CGFloat = 500"))
        #expect(onboarding.contains(
            ".frame(width: OnboardingLayout.width, height: OnboardingLayout.height)"
        ))
        #expect(renderer.contains("size: OnboardingLayout.size"))
        #expect(!onboarding.contains(".frame(width: 600, height: 640)"))
        #expect(!renderer.contains("size: CGSize(width: 600, height: 640)"))
    }

    @Test func liveDisclosuresUseOneExplicitAccessibleButtonControl() throws {
        let components = try repositoryFile("App/Sources/UI/Components.swift")
        let disclosureSurfaces = try [
            "App/Sources/UI/Main/CutoffsPane.swift",
            "App/Sources/UI/Main/SetupPane.swift",
            "App/Sources/UI/Onboarding/OnboardingView.swift",
        ].map(repositoryFile).joined(separator: "\n")

        #expect(components.contains("struct AccessibleDisclosure<Content: View>: View"))
        #expect(components.contains("@Binding private var isExpanded: Bool"))
        #expect(components.contains("Button {\n                isExpanded.toggle()"))
        #expect(components.contains(".accessibilityValue(isExpanded ? \"Expanded\" : \"Collapsed\")"))
        #expect(components.contains(".accessibilityHint(accessibilityHint)"))
        #expect(disclosureSurfaces.contains("AccessibleDisclosure("))
        #expect(!disclosureSurfaces.contains("DisclosureGroup("))
        #expect(!disclosureSurfaces.contains("isExpanded: .constant(true)"))
    }

    @Test func everySafetySettingSwitchHasAnExplicitNameAndHint() throws {
        let cutoffs = try repositoryFile("App/Sources/UI/Main/CutoffsPane.swift")
        let schedules = try repositoryFile("App/Sources/UI/Main/SchedulesPane.swift")

        for name in [
            "Battery floor",
            "Thermal protection",
            "Duration limit",
            "Off-time",
            "Request sleep at cutoff",
            "Notify on arm, disarm and cutoff",
            "Play sound at cutoff",
            "Low Power Mode while armed",
            "Keep network alive",
            "Show countdown in menu bar",
        ] {
            #expect(cutoffs.contains(".accessibilityLabel(\"\(name)\")"))
        }
        #expect(cutoffs.contains(".accessibilityHint("))
        #expect(schedules.contains(
            ".accessibilityLabel(\"Arm automatically on schedule\")"
        ))
        #expect(schedules.contains(".accessibilityHint("))
    }

    @Test func simulationCannotBeBlockedByUnsignedWidgetOrNotificationServices() throws {
        let appState = try repositoryFile("App/Sources/AppState.swift")

        #expect(appState.contains("self.notifications.suppressed = simulated"))
        #expect(appState.contains(
            "private func publishWidget() -> Bool {\n        guard !isSimulation else { return true }"
        ))
    }

    @Test func populatedHistoryFitsAndRendersAtEverySupportedWindowSize() throws {
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")
        let renderer = try repositoryFile(
            "App/Sources/Services/ScreenshotRenderer.swift"
        )
        let contactSheet = try repositoryFile(
            "Scripts/VisualQA/ContactSheet.swift"
        )

        #expect(history.contains(
            ".frame(minWidth: 220, idealWidth: 260, maxWidth: 300)"
        ))
        #expect(history.contains(
            ".frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)"
        ))
        #expect(!history.contains(".frame(minWidth: 240, idealWidth: 300, maxWidth: 360)"))
        #expect(!history.contains(".frame(minWidth: 300, idealWidth: 340, maxWidth: 420)"))
        #expect(!history.contains(".frame(minWidth: 380, maxWidth: .infinity"))

        #expect(renderer.contains("for size in ShellRenderSize.allCases"))
        for filename in [
            "secondary-history-empty-minimum.png",
            "secondary-history-empty-default.png",
            "secondary-history-empty-wide.png",
            "secondary-history-selected-minimum.png",
            "secondary-history-selected-default.png",
            "secondary-history-selected-wide.png",
        ] {
            #expect(contactSheet.contains(filename))
        }
    }

    @Test func chartsExposeOneUsefulSummaryInsteadOfRawUnknownMarks() throws {
        let overview = try repositoryFile("App/Sources/UI/Main/OverviewPane.swift")
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")
        let onboarding = try repositoryFile(
            "App/Sources/UI/Onboarding/OnboardingView.swift"
        )

        #expect(overview.contains(".accessibilityElement(children: .ignore)"))
        #expect(overview.contains(".accessibilityLabel(\"Battery trend\")"))
        #expect(overview.contains(".accessibilityValue(accessibilitySummary)"))
        #expect(history.contains(".accessibilityHidden(true)"))
        #expect(onboarding.contains(
            "LidSeamMark()\n                    .frame(width: 76, height: 76)\n                    .accessibilityHidden(true)"
        ))
    }

    @Test func historyDetailStatsReflowBeforeTheyCanClipTheMinimumWindow() throws {
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")

        #expect(history.contains("GeometryReader { proxy in"))
        #expect(history.contains("if proxy.size.width >= 390"))
        #expect(!history.contains("ViewThatFits(in: .horizontal)"))
        #expect(history.contains(".frame(width: 110)"))
        #expect(!history.contains(".frame(minWidth: 380)"))
        #expect(history.contains("private var stackedStats: some View"))
        #expect(history.contains("VStack(spacing: Theme.s2)"))
    }

    @Test func scheduleEditorKeepsActionsReachableAtMaximumTextSize() throws {
        let schedules = try repositoryFile(
            "App/Sources/UI/Main/SchedulesPane.swift"
        )
        let renderer = try repositoryFile(
            "App/Sources/Services/ScreenshotRenderer.swift"
        )
        let contactSheet = try repositoryFile(
            "Scripts/VisualQA/ContactSheet.swift"
        )

        #expect(schedules.contains("enum ScheduleEditorLayout"))
        #expect(schedules.contains("struct ScheduleWindowEditor"))
        #expect(schedules.contains("ScrollView {"))
        #expect(schedules.contains("ViewThatFits(in: .horizontal)"))
        #expect(schedules.contains("private var actionBar: some View"))
        #expect(schedules.contains(".frame(width: ScheduleEditorLayout.width"))
        #expect(renderer.contains("accessibility-schedule-editor.png"))
        #expect(renderer.contains("ScheduleWindowEditor("))
        #expect(contactSheet.contains("accessibility-schedule-editor.png"))
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
