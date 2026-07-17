import SwiftUI
import LidlessCore

struct MainWindowView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.mainPane) {
                ForEach(visiblePanes) { pane in
                    Label(pane.title, systemImage: pane.systemImage)
                        .tag(pane)
                }
            }
            .navigationSplitViewColumnWidth(min: 176, ideal: 196, max: 240)
        } detail: {
            ZStack {
                AuroraBackground(mood: state.mood)
                    .opacity(0.6)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .fontDesign(.rounded)
        .sheet(isPresented: Binding(
            get: { !state.config.onboardingComplete },
            set: { presented in state.config.onboardingComplete = !presented }
        )) {
            OnboardingView()
                .environment(state)
        }
    }

    private var visiblePanes: [AppState.MainPane] {
        AppState.MainPane.allCases.filter { $0 != .simulator || state.isSimulation }
    }

    @ViewBuilder
    private var detail: some View {
        switch state.mainPane {
        case .overview: OverviewPane()
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
        case .overview: "eye"
        case .cutoffs: "moon.zzz"
        case .schedules: "calendar.badge.clock"
        case .history: "clock.arrow.circlepath"
        case .setup: "wrench.and.screwdriver"
        case .simulator: "slider.horizontal.3"
        }
    }
}
