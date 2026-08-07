import AppKit
import SwiftUI
import LidlessCore

// MARK: - Deterministic visual states

enum InstrumentConfirmationTone {
    case normal
    case caution
    case critical
}

struct InstrumentRenderEvidence {
    var symbol: String
    var text: String
}

struct InstrumentRenderConfirmation {
    var title: String
    var symbol: String
    var message: String?
    var evidence: [InstrumentRenderEvidence]
    var tone: InstrumentConfirmationTone
    var allowsArm: Bool
    var confirmTitle: String
}

struct InstrumentRenderBanner {
    var kind: BannerKind
    var message: String
    var actionTitle: String?
}

/// Screenshot-only presentation values. They never mutate AppState, never
/// persist, and are admitted only by the guarded simulation renderer below.
enum InstrumentRenderScenario: String, CaseIterable {
    case verifiedNormal
    case confirmationOK
    case confirmationLowBattery
    case confirmationFloorRefusal
    case confirmationThermalRefusal
    case verifiedArmed
    case restoring
    case outsideOverride
    case unknown
    case helperSetup
    case longError

    static let panelMatrix: [InstrumentRenderScenario] = [
        .verifiedNormal,
        .confirmationOK,
        .confirmationLowBattery,
        .confirmationFloorRefusal,
        .confirmationThermalRefusal,
        .verifiedArmed,
        .restoring,
        .outsideOverride,
        .unknown,
        .helperSetup,
        .longError,
    ]

    static let shellMatrix: [InstrumentRenderScenario] = [
        .verifiedNormal,
        .verifiedArmed,
        .outsideOverride,
        .unknown,
    ]

    var presentation: SleepPresentationState {
        switch self {
        case .verifiedNormal,
             .confirmationOK,
             .confirmationLowBattery,
             .confirmationFloorRefusal,
             .confirmationThermalRefusal,
             .helperSetup:
            .verifiedNormal
        case .verifiedArmed:
            .verifiedArmed
        case .restoring:
            .restoring
        case .outsideOverride:
            .outsideOverride
        case .unknown:
            .unknown
        case .longError:
            .unknown
        }
    }

    var panelFilename: String {
        switch self {
        case .verifiedNormal: "menu-verified-normal.png"
        case .confirmationOK: "menu-confirmation-ok.png"
        case .confirmationLowBattery: "menu-confirmation-low-battery.png"
        case .confirmationFloorRefusal: "menu-confirmation-floor-refusal.png"
        case .confirmationThermalRefusal: "menu-confirmation-thermal-refusal.png"
        case .verifiedArmed: "menu-verified-armed.png"
        case .restoring: "menu-restoring.png"
        case .outsideOverride: "menu-outside-override.png"
        case .unknown: "menu-unknown.png"
        case .helperSetup: "menu-helper-setup.png"
        case .longError: "menu-long-error.png"
        }
    }

    var slug: String {
        switch self {
        case .verifiedNormal: "verified-normal"
        case .verifiedArmed: "verified-armed"
        case .outsideOverride: "outside-override"
        case .unknown: "unknown"
        default: rawValue
        }
    }

    var headline: String {
        switch presentation {
        case .verifiedNormal: "Sleeping normally"
        case .verifyingArm: "Verifying keep-awake"
        case .verifiedArmed: "Keeping this Mac awake"
        case .restoring: "Restoring normal sleep"
        case .outsideOverride: "Sleep override outside Lidless"
        case .unknown: "System sleep is unverified"
        }
    }

    var detail: String? {
        switch self {
        case .verifiedNormal,
             .confirmationOK,
             .confirmationLowBattery,
             .confirmationFloorRefusal,
             .confirmationThermalRefusal:
            "The system override is off and normal sleep is verified."
        case .verifiedArmed:
            "A verified Lidless session owns the active sleep override."
        case .restoring:
            "The restore request is active. Keep Lidless open until proof completes."
        case .outsideOverride:
            "The system override is active without a verified Lidless session."
        case .unknown, .longError:
            "Fresh registry evidence is unavailable, so Lidless cannot claim success."
        case .helperSetup:
            "Normal sleep is verified, but keep-awake needs one-time helper setup."
        }
    }

    var proof: String {
        switch presentation {
        case .verifiedNormal:
            "Registry proof confirms the system override is off"
        case .verifiedArmed:
            "Helper ownership and the registry override are verified"
        case .restoring:
            "Normal sleep has not been re-verified yet"
        case .outsideOverride:
            "The registry override has no verified Lidless owner"
        case .unknown:
            "No current registry proof is available"
        case .verifyingArm:
            "Waiting for helper ownership and registry proof"
        }
    }

    var cutoffText: String? {
        self == .verifiedArmed ? "2 hr 18 min · Until battery reaches 20%" : nil
    }

    var banner: InstrumentRenderBanner? {
        switch self {
        case .outsideOverride:
            InstrumentRenderBanner(
                kind: .warning,
                message: "A system-wide sleep override is active without a verified Lidless session.",
                actionTitle: nil
            )
        case .unknown:
            InstrumentRenderBanner(
                kind: .error,
                message: "Lidless cannot currently verify whether normal sleep is enabled.",
                actionTitle: nil
            )
        case .helperSetup:
            InstrumentRenderBanner(
                kind: .info,
                message: "Install the privileged helper once to enable verified keep-awake requests.",
                actionTitle: "Open Setup…"
            )
        case .longError:
            InstrumentRenderBanner(
                kind: .error,
                message: "Lidless could not complete the request because current helper ownership and the system registry result did not agree. Normal sleep has not been claimed as restored. Open Setup for the verified recovery path and keep the helper registered until recovery is complete.",
                actionTitle: nil
            )
        default:
            nil
        }
    }

    var confirmation: InstrumentRenderConfirmation? {
        switch self {
        case .confirmationOK:
            InstrumentRenderConfirmation(
                title: "Keep this Mac awake with the lid closed?",
                symbol: "checkmark.shield",
                message: "Review the safeguards that will request and verify normal sleep.",
                evidence: [
                    .init(symbol: "gauge.with.needle", text: "About 7 hr 30 min of battery at 9.0%/hr"),
                    .init(symbol: "battery.25percent", text: "Requests normal sleep at the 20% battery floor"),
                    .init(symbol: "thermometer.medium", text: "Thermal protection remains enabled"),
                ],
                tone: .normal,
                allowsArm: true,
                confirmTitle: "Keep Awake"
            )
        case .confirmationLowBattery:
            InstrumentRenderConfirmation(
                title: "Battery is low",
                symbol: "exclamationmark.triangle.fill",
                message: "Battery is 24%. The configured 20% floor leaves a narrow margin.",
                evidence: [
                    .init(symbol: "battery.25percent", text: "Requests normal sleep at 20%"),
                    .init(symbol: "clock", text: "Projected margin is about 27 minutes"),
                    .init(symbol: "thermometer.medium", text: "Thermal protection remains enabled"),
                ],
                tone: .caution,
                allowsArm: true,
                confirmTitle: "Keep Awake"
            )
        case .confirmationFloorRefusal:
            InstrumentRenderConfirmation(
                title: "Battery floor blocks this request",
                symbol: "battery.0percent",
                message: "Battery is 19%, below the configured 20% safety floor.",
                evidence: [
                    .init(symbol: "powerplug", text: "Charge the Mac before trying again"),
                    .init(symbol: "gearshape", text: "Safety settings remain unchanged"),
                ],
                tone: .critical,
                allowsArm: false,
                confirmTitle: "Can't Continue"
            )
        case .confirmationThermalRefusal:
            InstrumentRenderConfirmation(
                title: "Thermal protection blocks this request",
                symbol: "thermometer.high",
                message: "The current thermal reading already triggers the configured guard.",
                evidence: [
                    .init(symbol: "snowflake", text: "Let the Mac cool before trying again"),
                    .init(symbol: "checkmark.shield", text: "No sleep override will be requested"),
                ],
                tone: .critical,
                allowsArm: false,
                confirmTitle: "Can't Continue"
            )
        default:
            nil
        }
    }

    var primaryActionAvailable: Bool {
        switch self {
        case .restoring, .helperSetup:
            false
        default:
            confirmation == nil
        }
    }

    var batteryValue: String {
        switch self {
        case .confirmationLowBattery: "24%"
        case .confirmationFloorRefusal: "19%"
        default: presentation == .unknown ? "—" : "68%"
        }
    }

    var batteryCaption: String {
        presentation == .unknown ? "Unverified" : "On battery"
    }

    var batterySymbol: String {
        switch self {
        case .confirmationLowBattery, .confirmationFloorRefusal:
            "battery.25percent"
        case .unknown, .longError:
            "questionmark.circle"
        default:
            "battery.75percent"
        }
    }

    var drainValue: String {
        presentation == .unknown ? "—" : "9.0%/hr"
    }

    var thermalValue: String {
        if presentation == .unknown { return "—" }
        return self == .confirmationThermalRefusal ? "High" : "Nominal"
    }

    var thermalCaption: String {
        if presentation == .unknown { return "Unverified" }
        return self == .confirmationThermalRefusal ? "Elevated" : "Thermals"
    }

    var thermalIsElevated: Bool {
        self == .confirmationThermalRefusal
    }
}

enum ShellRenderSize: String, CaseIterable {
    case minimum
    case defaultSize = "default"
    case wide

    var size: CGSize {
        switch self {
        case .minimum: CGSize(width: 840, height: 560)
        case .defaultSize: CGSize(width: 900, height: 620)
        case .wide: CGSize(width: 1280, height: 800)
        }
    }

    func filename(for scenario: InstrumentRenderScenario) -> String {
        "window-\(rawValue)-\(scenario.slug).png"
    }
}

// MARK: - Renderer

@MainActor
enum ScreenshotRenderer {
    static let onboardingEvidenceFilenames = [
        "onboarding-intro.png",
        "onboarding-helper.png",
        "onboarding-recovery.png",
        "onboarding-helper-failure.png",
    ]

    /// Widget views live in their own target and the icon is drawn by the local
    /// vector generator. Their filenames are still part of this evidence
    /// manifest so a screenshot run has one auditable matrix.
    static let externallyRenderedEvidenceFilenames = [
        "widget-small-verified-normal.png",
        "widget-medium-verified-armed.png",
        "widget-small-stale-unknown.png",
        "widget-medium-empty.png",
        "icon-contact-sheet.png",
    ]

    static func renderAndExit(state: AppState) {
        Task { @MainActor in
            let code: Int32
            do {
                try await render(state: state)
                code = 0
            } catch {
                FileHandle.standardError.write(
                    Data("screenshot render failed: \(error)\n".utf8)
                )
                code = 1
            }
            exit(code)
        }
    }

    static func render(state: AppState) async throws {
        guard state.isSimulation, let simulation = state.simulation else {
            throw NSError(domain: "Lidless", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "screenshots require simulation",
            ])
        }

        state.notifications.suppressed = true
        state.config.onboardingComplete = true
        state.mainPane = .overview

        simulation.batteryPercent = 68
        simulation.onBattery = true
        simulation.charging = false
        simulation.drainPerHour = 9
        simulation.thermalWarningLevel = 0
        simulation.cpuSpeedLimit = 100
        simulation.processLevel = .nominal
        simulation.lidClosed = false

        let now = Date(timeIntervalSince1970: 1_786_117_600)
        state.seedRollingSamplesForRendering((0...12).map { index in
            BatterySample(
                time: now.addingTimeInterval(TimeInterval(index - 12) * 900),
                percent: 68 + Double(12 - index) * 2.25,
                isDischarging: true
            )
        })
        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Docs/screenshots", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        for scenario in InstrumentRenderScenario.panelMatrix {
            try write(
                panel(state, scenario: scenario),
                to: outputDirectory.appendingPathComponent(scenario.panelFilename)
            )
        }

        for size in ShellRenderSize.allCases {
            for scenario in InstrumentRenderScenario.shellMatrix {
                try write(
                    shell(state, scenario: scenario, size: size.size),
                    to: outputDirectory.appendingPathComponent(
                        size.filename(for: scenario)
                    )
                )
            }
        }

        try renderSecondaryEvidence(
            state: state,
            now: now,
            outputDirectory: outputDirectory
        )

        for scenario in OnboardingRenderScenario.allCases {
            try write(
                hostedImage(
                    OnboardingView(renderScenario: scenario).environment(state),
                    size: OnboardingLayout.size
                ),
                to: outputDirectory.appendingPathComponent(scenario.filename)
            )
        }

        // Stable aliases retained for existing README references.
        try write(
            panel(state, scenario: .verifiedNormal),
            to: outputDirectory.appendingPathComponent("menu-disarmed.png")
        )
        try write(
            panel(state, scenario: .confirmationOK),
            to: outputDirectory.appendingPathComponent("menu-confirm.png")
        )
        try write(
            panel(state, scenario: .verifiedArmed),
            to: outputDirectory.appendingPathComponent("menu-armed.png")
        )
        try write(
            shell(
                state,
                scenario: .verifiedArmed,
                size: ShellRenderSize.defaultSize.size
            ),
            to: outputDirectory.appendingPathComponent("window-overview.png")
        )
        try write(
            hostedImage(
                OnboardingView(renderScenario: .intro).environment(state),
                size: OnboardingLayout.size
            ),
            to: outputDirectory.appendingPathComponent("onboarding.png")
        )

        print("screenshots written to \(outputDirectory.path)")
    }

    private static func panel(
        _ state: AppState,
        scenario: InstrumentRenderScenario
    ) -> NSImage? {
        image(
            MenuPanelView(renderScenario: scenario)
                .environment(state)
                .frame(width: Theme.panelWidth)
        )
    }

    private static func shell(
        _ state: AppState,
        scenario: InstrumentRenderScenario,
        size: CGSize
    ) -> NSImage? {
        hostedImage(
            MainWindowView(renderScenario: scenario)
                .environment(state),
            size: size
        )
    }

    private static func renderSecondaryEvidence(
        state: AppState,
        now: Date,
        outputDirectory: URL
    ) throws {
        let defaultSize = CGSize(width: 900, height: 620)

        try write(
            secondaryPane(CutoffsPane(), state: state, size: defaultSize),
            to: outputDirectory.appendingPathComponent("secondary-cutoffs-default.png")
        )

        state.config.schedules = []
        try write(
            secondaryPane(SchedulesPane(), state: state, size: defaultSize),
            to: outputDirectory.appendingPathComponent("secondary-schedules-empty.png")
        )

        state.config.schedules = [
            ScheduleWindow.weeknights(),
            ScheduleWindow(
                enabled: false,
                weekdays: [6, 7],
                start: HMTime(hour: 21, minute: 30),
                end: HMTime(hour: 6, minute: 30)
            ),
        ]
        try write(
            secondaryPane(SchedulesPane(), state: state, size: defaultSize),
            to: outputDirectory.appendingPathComponent("secondary-schedules-populated.png")
        )

        _ = state.sessionStore.clearHistory()
        for size in ShellRenderSize.allCases {
            try write(
                secondaryPane(
                    HistoryPane(rendersEvidence: true),
                    state: state,
                    size: size.size
                ),
                to: outputDirectory.appendingPathComponent(
                    "secondary-history-empty-\(size.rawValue).png"
                )
            )
        }
        try write(
            secondaryPane(
                HistoryPane(rendersEvidence: true),
                state: state,
                size: defaultSize
            ),
            to: outputDirectory.appendingPathComponent("secondary-history-empty.png")
        )

        let sessionID = UUID(uuidString: "10D1E550-75A7-4F4B-A6D0-0E73ED771355")!
        let startedAt = now.addingTimeInterval(-4 * 3600)
        let session = KeepAwakeSession(
            id: sessionID,
            startedAt: startedAt,
            endedAt: now,
            endReason: .cutoff(.batteryFloor(percent: 68, floor: 68)),
            source: .manual,
            startPercent: 92,
            endPercent: 68,
            samples: (0...8).map { index in
                BatterySample(
                    time: startedAt.addingTimeInterval(Double(index) * 1800),
                    percent: 92 - Double(index) * 3,
                    isDischarging: true
                )
            },
            cutoffSummary: "Battery floor 68% · Thermal guard enabled",
            lowPowerModeUsed: true,
            tcpKeepAliveUsed: true
        )
        _ = state.sessionStore.append(session)
        for size in ShellRenderSize.allCases {
            try write(
                secondaryPane(
                    HistoryPane(initialSelection: sessionID, rendersEvidence: true),
                    state: state,
                    size: size.size
                ),
                to: outputDirectory.appendingPathComponent(
                    "secondary-history-selected-\(size.rawValue).png"
                )
            )
        }
        try write(
            secondaryPane(
                HistoryPane(initialSelection: sessionID, rendersEvidence: true),
                state: state,
                size: defaultSize
            ),
            to: outputDirectory.appendingPathComponent("secondary-history-selected.png")
        )

        try write(
            secondaryPane(
                SetupPane(),
                state: state,
                size: CGSize(width: 900, height: 700)
            ),
            to: outputDirectory.appendingPathComponent("secondary-setup-simulated.png")
        )
        try write(
            secondaryPane(SimulatorPane(), state: state, size: defaultSize),
            to: outputDirectory.appendingPathComponent("secondary-simulator-default.png")
        )
    }

    private static func secondaryPane(
        _ content: some View,
        state: AppState,
        size: CGSize
    ) -> NSImage? {
        hostedImage(
            NavigationStack { content }
                .environment(state),
            size: size
        )
    }

    /// The screenshot branch of MainWindowView avoids window-server-backed
    /// vibrancy, but still needs AppKit layout to realize its responsive cards.
    private static func hostedImage(
        _ content: some View,
        size: CGSize
    ) -> NSImage? {
        let hostingView = NSHostingView(
            rootView: content
                .frame(width: size.width, height: size.height)
                .background(Theme.canvas)
                .environment(\.colorScheme, .dark)
        )
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        let scale: CGFloat = 2
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        representation.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

        let image = NSImage(size: size)
        image.addRepresentation(representation)
        return image
    }

    private static func window(_ content: some View, size: CGSize) -> NSImage? {
        image(content.frame(width: size.width, height: size.height))
    }

    private static func image(_ content: some View) -> NSImage? {
        let renderer = ImageRenderer(
            content: content
                .background(Theme.canvas)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2
        return renderer.nsImage
    }

    private static func write(_ image: NSImage?, to url: URL) throws {
        guard let image,
              let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let png = representation.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "Lidless", code: 11, userInfo: [
                NSLocalizedDescriptionKey: "could not rasterize \(url.lastPathComponent)",
            ])
        }
        try png.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }
}
