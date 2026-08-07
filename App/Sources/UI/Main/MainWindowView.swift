import SwiftUI
import LidlessCore

struct MainWindowView: View {
    @Environment(AppState.self) private var state

    var renderScenario: InstrumentRenderScenario? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var state = state

        Group {
            if renderScenario == nil {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    List(selection: $state.mainPane) {
                        Section("Control Center") {
                            ForEach(visiblePanes) { pane in
                                Label(pane.title, systemImage: pane.systemImage)
                                    .tag(pane)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .navigationTitle("Lidless")
                    .navigationSplitViewColumnWidth(min: 176, ideal: 196, max: 240)
                } detail: {
                    detail
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .background(Theme.canvas)
                        .toolbar {
                            ToolbarItem(placement: .automatic) {
                                StatusPill(presentation: presentation)
                            }
                        }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                deterministicShell
            }
        }
        .background(Theme.canvas)
        .preferredColorScheme(.dark)
        .sheet(isPresented: Binding(
            get: { !state.config.onboardingComplete },
            set: { presented in state.config.onboardingComplete = !presented }
        )) {
            OnboardingView()
                .environment(state)
        }
    }

    private var deterministicShell: some View {
        HStack(spacing: 0) {
            deterministicSidebar
                .frame(width: 196)

            Rectangle()
                .fill(Theme.separator)
                .frame(width: 1)

            detail
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(Theme.canvas)
        }
        .background(Theme.canvas)
    }

    private var presentation: SleepPresentationState {
        renderScenario?.presentation ?? state.sleepPresentation
    }

    private var visiblePanes: [AppState.MainPane] {
        AppState.MainPane.allCases.filter { $0 != .simulator || state.isSimulation }
    }

    /// Native sidebar lists rely on window-server vibrancy and can lose their
    /// labels in an off-screen bitmap. The renderer uses the same navigation
    /// model in a fixed, non-vibrant treatment so screenshot QA remains useful.
    private var deterministicSidebar: some View {
        VStack(alignment: .leading, spacing: Theme.s1) {
            Text("Lidless")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, Theme.s2)
                .padding(.bottom, Theme.s3)

            Text("CONTROL CENTER")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, Theme.s2)
                .padding(.bottom, Theme.s1)

            ForEach(visiblePanes) { pane in
                let selected = pane == state.mainPane
                HStack(spacing: Theme.s2) {
                    Image(systemName: pane.systemImage)
                        .frame(width: Theme.s5)
                    Text(pane.title)
                    Spacer(minLength: 0)
                }
                .font(.callout.weight(selected ? .medium : .regular))
                .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, Theme.s2)
                .frame(minHeight: 32)
                .background(
                    selected ? Theme.surfaceElevated : Color.clear,
                    in: RoundedRectangle(
                        cornerRadius: Theme.controlRadius,
                        style: .continuous
                    )
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.s2)
        .padding(.vertical, Theme.s4)
        .background(Theme.surface)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.mainPane {
        case .overview: OverviewPane(renderScenario: renderScenario)
        case .cutoffs: CutoffsPane()
        case .schedules: SchedulesPane()
        case .history: HistoryPane()
        case .setup: SetupPane()
        case .simulator: SimulatorPane()
        }
    }
}

extension AppState.MainPane {
    var title: String {
        switch self {
        case .overview: "Overview"
        case .cutoffs: "Cutoffs"
        case .schedules: "Schedules"
        case .history: "History"
        case .setup: "Setup & Help"
        case .simulator: "Simulator"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "gauge.with.needle"
        case .cutoffs: "moon.zzz"
        case .schedules: "calendar.badge.clock"
        case .history: "clock.arrow.circlepath"
        case .setup: "wrench.and.screwdriver"
        case .simulator: "slider.horizontal.3"
        }
    }
}
