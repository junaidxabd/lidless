import Foundation
import Testing

@Suite("Quiet native menu and shell contracts")
struct VisualSystemSourceTests {
    @Test func menuUsesOneProofDrivenActionAndExplicitConfirmation() throws {
        let menu = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")

        for required in [
            ".frame(width: Theme.panelWidth)",
            "StatusPill(presentation: presentation)",
            "PrimaryActionButton(",
            "state.beginArmFlow()",
            "await state.disarm()",
            "await state.repairOverride()",
            "await state.refreshHelperState()",
            "Button(\"Cancel\")",
            ".keyboardShortcut(.cancelAction)",
            ".keyboardShortcut(.defaultAction)",
            "@Environment(\\.accessibilityReduceMotion)",
            "ScrollView",
            "Menu {",
        ] {
            #expect(menu.contains(required))
        }

        #expect(menu.contains("if let confirmation = renderScenario?.confirmation"))
        #expect(menu.contains("else if let pending = state.pendingArm"))
        #expect(menu.contains("if hasConfirmation"))
        #expect(menu.contains("case .unknown, .notResponding, .stale:"))
        #expect(menu.contains("Public replacement is disabled"))
        #expect(!menu.contains("isReviewedStaleReplacementCompatible"))
        #expect(!menu.contains("needs a safety update"))
        #expect(!menu.contains("GlassSwitch("))
        #expect(!repositoryFileExists("App/Sources/UI/MenuBar/GlassSwitch.swift"))
    }

    @Test func deterministicPanelMatrixCoversEverySafetyVerdict() throws {
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")

        for scenario in [
            "case verifiedNormal",
            "case noBattery",
            "case charging",
            "case verifyingArm",
            "case confirmationOK",
            "case confirmationLowBattery",
            "case confirmationFloorRefusal",
            "case confirmationThermalRefusal",
            "case verifiedArmed",
            "case restoring",
            "case outsideOverride",
            "case unknown",
            "case helperSetup",
            "case longError",
        ] {
            #expect(renderer.contains(scenario))
        }

        for filename in [
            "menu-verified-normal.png",
            "menu-no-battery.png",
            "menu-charging.png",
            "menu-verifying-arm.png",
            "menu-confirmation-ok.png",
            "menu-confirmation-low-battery.png",
            "menu-confirmation-floor-refusal.png",
            "menu-confirmation-thermal-refusal.png",
            "menu-verified-armed.png",
            "menu-restoring.png",
            "menu-outside-override.png",
            "menu-unknown.png",
            "menu-helper-setup.png",
            "menu-long-error.png",
        ] {
            #expect(renderer.contains(filename))
        }

        #expect(renderer.contains("guard state.isSimulation"))
        #expect(renderer.contains("for scenario in InstrumentRenderScenario.panelMatrix"))
        #expect(renderer.contains("MenuPanelView(renderScenario: scenario)"))
    }

    @Test func nativeShellRendersEveryStateAtMinimumDefaultAndWideSizes() throws {
        let shell = try repositoryFile("App/Sources/UI/Main/MainWindowView.swift")
        let overview = try repositoryFile("App/Sources/UI/Main/OverviewPane.swift")
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")

        #expect(shell.contains("NavigationSplitView"))
        #expect(shell.contains(".listStyle(.sidebar)"))
        #expect(shell.contains(".toolbar"))
        #expect(shell.contains("OverviewPane(renderScenario: renderScenario)"))
        #expect(shell.contains("deterministicSidebar"))
        #expect(shell.contains("renderScenario == nil"))
        #expect(overview.contains("StatusPill(presentation: presentation)"))
        #expect(overview.contains("PrimaryActionButton("))
        #expect(overview.contains("ViewThatFits(in: .horizontal)"))
        #expect(overview.contains("currentSafeguardsCard"))
        #expect(overview.contains("batteryLedgerCard"))
        #expect(overview.contains("ScrollView"))
        #expect(overview.contains(".scrollIndicators(.automatic)"))

        for size in [
            "CGSize(width: 840, height: 560)",
            "CGSize(width: 900, height: 620)",
            "CGSize(width: 1280, height: 800)",
        ] {
            #expect(renderer.contains(size))
        }
        #expect(renderer.contains("for size in ShellRenderSize.allCases"))
        #expect(renderer.contains("for scenario in InstrumentRenderScenario.shellMatrix"))
        #expect(renderer.contains("MainWindowView(renderScenario: scenario)"))
    }

    @Test func overviewTransitionEvidenceCoversProgressAndConfirmationsAtEverySize() throws {
        let menu = try repositoryFile("App/Sources/UI/MenuBar/MenuPanelView.swift")
        let overview = try repositoryFile("App/Sources/UI/Main/OverviewPane.swift")
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")
        let contactSheet = try repositoryFile("Scripts/VisualQA/ContactSheet.swift")

        #expect(renderer.contains("case verifyingArm"))
        #expect(renderer.contains("static let shellTransitionMatrix"))
        for scenario in [
            ".verifyingArm",
            ".restoring",
            ".confirmationOK",
            ".confirmationLowBattery",
            ".confirmationFloorRefusal",
            ".confirmationThermalRefusal",
        ] {
            #expect(renderer.contains(scenario))
        }

        #expect(overview.contains("if let confirmation = renderScenario?.confirmation"))
        #expect(overview.contains("RenderArmConfirmationCard(confirmation: confirmation)"))
        #expect(menu.contains("struct RenderArmConfirmationCard: View"))
        #expect(!menu.contains("private struct RenderArmConfirmationCard: View"))

        for slug in [
            "verifying-arm",
            "restoring",
            "confirmation-ok",
            "confirmation-low-battery",
            "confirmation-floor-refusal",
            "confirmation-thermal-refusal",
        ] {
            for size in ["minimum", "default", "wide"] {
                #expect(contactSheet.contains("window-\(size)-\(slug).png"))
            }
        }
        #expect(contactSheet.contains("window-transition-contact-sheet.png"))
    }

    @Test func accessibilityStressMatrixCoversDenseAndNarrowSurfaces() throws {
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")
        let contactSheet = try repositoryFile("Scripts/VisualQA/ContactSheet.swift")

        #expect(renderer.contains(".environment(\\.dynamicTypeSize, .accessibility5)"))
        for filename in [
            "accessibility-menu-long-error.png",
            "accessibility-window-minimum-confirmation.png",
            "accessibility-onboarding-recovery.png",
            "accessibility-schedule-editor.png",
        ] {
            #expect(renderer.contains(filename))
            #expect(contactSheet.contains(filename))
        }
        #expect(contactSheet.contains("accessibility-contact-sheet.png"))
    }

    @Test func longErrorFixtureCannotClaimVerifiedNormalState() throws {
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")

        #expect(renderer.contains("case .longError:\n            .unknown"))
        #expect(renderer.contains("presentation == .unknown ? \"—\" : \"68%\""))
        #expect(renderer.contains("presentation == .unknown ? \"Unverified\" : \"On battery\""))
    }

    @Test func rebuiltSurfacesContainNoRejectedVisualLanguage() throws {
        let paths = [
            "App/Sources/UI/MenuBar/MenuPanelView.swift",
            "App/Sources/UI/Main/MainWindowView.swift",
            "App/Sources/UI/Main/OverviewPane.swift",
        ]
        let source = try paths.map(repositoryFile).joined(separator: "\n")

        for forbidden in [
            "AuroraBackground",
            "GlowText",
            "LinearGradient(",
            "AngularGradient(",
            "RadialGradient(",
            ".glow(",
            ".blur(",
            ".shadow(",
            ".fontDesign(.rounded)",
            "design: .rounded",
            "systemImage: \"eye\"",
            "systemImage: \"eye.slash\"",
        ] {
            #expect(!source.contains(forbidden))
        }
    }

    @Test func secondaryPanesUseTruthfulCopyAndSafeNativeActions() throws {
        let schedules = try repositoryFile("App/Sources/UI/Main/SchedulesPane.swift")
        let cutoffs = try repositoryFile("App/Sources/UI/Main/CutoffsPane.swift")
        let setup = try repositoryFile("App/Sources/UI/Main/SetupPane.swift")

        for required in [
            "@State private var pendingDeletion: ScheduleWindow?",
            ".confirmationDialog(\n            \"Delete schedule?\"",
            ".accessibilityLabel(\"Edit schedule\")",
            ".accessibilityLabel(\"Delete schedule\")",
            "requests and verifies normal sleep",
        ] {
            #expect(schedules.contains(required))
        }
        #expect(!schedules.contains("Theme.armedGradient"))
        #expect(!schedules.contains("Restores normal sleep"))

        #expect(cutoffs.contains("requests normal sleep"))
        #expect(cutoffs.contains("asks macOS to sleep"))
        #expect(!cutoffs.contains("Forces sleep"))
        #expect(!cutoffs.contains("the reason this is safe"))

        #expect(setup.contains("terminalRecoveryDetail"))
        #expect(setup.contains("AccessibleDisclosure(\n                    \"Recovery details\""))
        #expect(setup.contains("Copy registry verification command"))
        #expect(setup.contains("Copy emergency recovery command"))
        #expect(setup.contains("requires a reviewed removal procedure"))
        #expect(setup.contains("Public cleanup and replacement are disabled"))
        #expect(!setup.contains("isReviewedStaleReplacementCompatible"))
        #expect(!setup.contains("arrow.triangle.2.circlepath"))
        #expect(!setup.contains("uninstallSection"))
        #expect(!setup.contains("state.uninstall()"))
        #expect(!setup.contains("Uninstall Lidless"))
        #expect(!setup.contains("menu bar eye"))
    }

    @Test func onboardingWidgetAndIconUseTheDarkSafetyInstrument() throws {
        let onboarding = try repositoryFile("App/Sources/UI/Onboarding/OnboardingView.swift")
        let widget = try repositoryFile("Widget/Sources/LidlessWidget.swift")
        let icon = try repositoryFile("Scripts/make_icon.swift")
        let appState = try repositoryFile("App/Sources/AppState.swift")
        let entry = try repositoryFile("App/Sources/LidlessApp.swift")

        for required in [
            "enum OnboardingRenderScenario",
            "case intro",
            "case helper",
            "case recovery",
            "case helperFailure",
            "ScrollView",
            "AccessibleDisclosure(\n                    \"Recovery details\"",
        ] {
            #expect(onboarding.contains(required))
        }

        #expect(widget.contains("WidgetPalette.canvas"))
        #expect(widget.contains(".containerBackground(for: .widget)"))
        #expect(widget.contains("entry.isStale"))
        #expect(widget.contains("case .unknown: WidgetPalette.critical"))
        #expect(widget.contains("rendersStaticActions"))
        #expect(widget.contains(
            "if entry.isStale {\n                StaleEvidenceView()\n            } else if entry.snapshot != nil"
        ))
        #expect(widget.contains("NO FRESH LIDLESS EVIDENCE"))
        #expect(widget.contains("Current sleep and battery state are unknown."))
        #expect(!widget.contains("Lidless isn't running"))

        for filename in [
            "icon_16x16.png",
            "icon_16x16@2x.png",
            "icon_32x32.png",
            "icon_32x32@2x.png",
            "icon_128x128.png",
            "icon_128x128@2x.png",
            "icon_256x256.png",
            "icon_256x256@2x.png",
            "icon_512x512.png",
            "icon_512x512@2x.png",
        ] {
            #expect(icon.contains(filename))
        }
        #expect(icon.contains("drawLidSeam"))
        #expect(icon.contains("drawWakeNotch"))

        #expect(appState.contains("case .verifiedNormal: \"moon.zzz\""))
        #expect(appState.contains("case .verifyingArm: \"hourglass\""))
        #expect(appState.contains("case .verifiedArmed: \"bolt\""))
        #expect(appState.contains("case .restoring: \"arrow.triangle.2.circlepath\""))
        #expect(appState.contains("case .outsideOverride: \"exclamationmark.triangle\""))
        #expect(appState.contains("case .unknown: \"questionmark.circle\""))

        let shippingPresentation = [onboarding, widget, icon, appState, entry]
            .joined(separator: "\n")
        for forbidden in [
            "AuroraBackground",
            "LinearGradient(",
            "NSGradient(",
            ".fontDesign(.rounded)",
            "eye.fill",
            "eye.slash",
            "eye.trianglebadge",
            "literal eye",
            "menu bar eye",
        ] {
            #expect(!shippingPresentation.contains(forbidden))
        }
    }

    @Test func rendererAndReadmeExposeTheCompleteEvidenceBoundary() throws {
        let renderer = try repositoryFile("App/Sources/Services/ScreenshotRenderer.swift")
        let readme = try repositoryFile("README.md")

        for filename in [
            "onboarding-intro.png",
            "onboarding-helper.png",
            "onboarding-recovery.png",
            "onboarding-helper-failure.png",
            "secondary-cutoffs-default.png",
            "secondary-schedules-empty.png",
            "secondary-schedules-populated.png",
            "secondary-history-empty.png",
            "secondary-history-selected.png",
            "secondary-setup-simulated.png",
            "secondary-simulator-default.png",
            "widget-small-verified-normal.png",
            "widget-medium-verified-armed.png",
            "widget-small-stale-unknown.png",
            "widget-medium-empty.png",
            "icon-contact-sheet.png",
        ] {
            #expect(renderer.contains(filename))
        }

        #expect(renderer.contains("HistoryPane(initialSelection:"))
        #expect(renderer.contains("for scenario in OnboardingRenderScenario.allCases"))
        #expect(!renderer.contains("enable safe keep-awake control"))

        let widget = try repositoryFile("Widget/Sources/LidlessWidget.swift")
        #expect(widget.contains("if rendersStaticActions {"))
        #expect(widget.contains("Text(staticCountdown(from: entry.date, to: cutoff))"))
        #expect(widget.contains("private func staticCountdown(from start: Date, to end: Date) -> String"))

        let widgetHarness = try repositoryFile(
            "Scripts/VisualQA/WidgetRenderHarness.swift"
        )
        let appHarness = try repositoryFile(
            "Scripts/VisualQA/AppRenderHarness.swift"
        )
        let contactSheet = try repositoryFile(
            "Scripts/VisualQA/ContactSheet.swift"
        )
        let visualScript = try repositoryFile(
            "Scripts/render_visual_evidence.sh"
        )
        #expect(widgetHarness.contains("for scenario in WidgetRenderScenario.allCases"))
        #expect(widgetHarness.contains("renderer.scale = 2"))
        #expect(appHarness.contains("let state = AppState.bootstrap()"))
        #expect(appHarness.contains("try await ScreenshotRenderer.render(state: state)"))
        #expect(contactSheet.contains("widget-contact-sheet.png"))
        #expect(contactSheet.contains("window-contact-sheet.png"))
        #expect(visualScript.contains("LIDLESS_TMP_ROOT"))
        #expect(visualScript.contains("export TMPDIR=\"$LIDLESS_TMP_ROOT\""))
        #expect(visualScript.contains("LIDLESS_APP_RENDER_HARNESS"))
        #expect(visualScript.contains("AppRenderHarness"))
        #expect(visualScript.contains("LIDLESS_WIDGET_RENDER_HARNESS"))
        #expect(visualScript.contains("-warnings-as-errors"))

        #expect(readme.localizedCaseInsensitiveContains("dark safety instrument"))
        #expect(readme.contains("Visual screenshots are interface evidence only"))
        #expect(!readme.localizedCaseInsensitiveContains("drifting aurora"))
        #expect(!readme.localizedCaseInsensitiveContains("literal eye"))
        #expect(!readme.contains("Setup & Help → Uninstall Lidless"))
    }

    @Test func historySelectionAndSimulatorEvidenceStayExplicit() throws {
        let history = try repositoryFile("App/Sources/UI/Main/HistoryPane.swift")
        let simulator = try repositoryFile("App/Sources/UI/Main/SimulatorPane.swift")

        #expect(history.contains("state.sessionStore.sessions.first(where: { $0.id == selectedID })"))
        #expect(!history.contains("?? state.sessionStore.sessions.first"))
        #expect(history.contains("ContentUnavailableView(\n                \"Select a session\""))
        #expect(history.contains("Button(\"Cancel\", role: .cancel)"))
        #expect(history.contains(".background(Theme.canvas)"))
        #expect(history.contains("deterministicHistoryList"))
        #expect(history.contains("rendersEvidence"))
        #expect(rendererSourceContainsHistoryEvidence())

        for required in [
            ".background(Theme.canvas)",
            ".accessibilityLabel(\"Simulated battery charge\")",
            ".accessibilityLabel(\"Simulated battery drain rate\")",
            ".accessibilityLabel(\"Simulation time scale\")",
            ".accessibilityLabel(\"Simulated CPU speed limit\")",
            "No system power settings are touched in simulation.",
        ] {
            #expect(simulator.contains(required))
        }

        let source = history + simulator
        for forbidden in [
            "LinearGradient(",
            "AuroraBackground",
            ".fontDesign(.rounded)",
            "systemImage: \"eye",
        ] {
            #expect(!source.contains(forbidden))
        }
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

    private func repositoryFileExists(_ relativePath: String) -> Bool {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default

        while directory.path != "/" {
            if fileManager.fileExists(
                atPath: directory.appendingPathComponent(relativePath).path
            ) {
                return true
            }
            directory.deleteLastPathComponent()
        }
        return false
    }

    private func rendererSourceContainsHistoryEvidence() -> Bool {
        guard let renderer = try? repositoryFile(
            "App/Sources/Services/ScreenshotRenderer.swift"
        ) else { return false }
        return renderer.contains("rendersEvidence: true")
    }
}
