import SwiftUI
import LidlessCore

/// Every automatic way a session ends, plus while-armed behavior. Grouped
/// form, advanced knobs behind disclosure — no settings sprawl.
struct CutoffsPane: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var config = state.config
        Form {
            Section {
                Toggle(isOn: $config.cutoffs.batteryFloorEnabled) {
                    Text("Battery floor")
                    Text("Lidless requests normal sleep when a verified discharging reading reaches the floor. Plugging in pauses this cutoff.")
                }
                if config.cutoffs.batteryFloorEnabled {
                    LabeledContent("Floor: \(config.cutoffs.batteryFloorPercent)%") {
                        Slider(
                            value: Binding(
                                get: { Double(config.cutoffs.batteryFloorPercent) },
                                set: { config.cutoffs.batteryFloorPercent = Int($0.rounded()) }
                            ),
                            in: 5...50,
                            step: 5
                        )
                        .frame(maxWidth: 240)
                    }
                }
            } header: {
                Text("Battery")
            }

            Section {
                Toggle(isOn: $config.cutoffs.thermalEnabled) {
                    Text("Thermal protection")
                    Text("Ends keep-awake when macOS reports a thermal warning or sustained CPU throttling. This guard is not proof that a closed or bagged Mac is thermally safe.")
                }
                if config.cutoffs.thermalEnabled {
                    DisclosureGroup("Advanced") {
                        Stepper(value: $config.cutoffs.thermalSpeedLimitFloor, in: 20...90, step: 5) {
                            LabeledContent("CPU speed cutoff", value: "below \(config.cutoffs.thermalSpeedLimitFloor)%")
                        }
                        Stepper(value: $config.cutoffs.thermalStrikesRequired, in: 1...5) {
                            LabeledContent("Consecutive readings required", value: "\(config.cutoffs.thermalStrikesRequired)")
                        }
                    }
                }
            } header: {
                Text("Thermal")
            }

            Section {
                Toggle(isOn: $config.cutoffs.durationEnabled) {
                    Text("Duration limit")
                }
                if config.cutoffs.durationEnabled {
                    Stepper(
                        value: Binding(
                            get: { config.cutoffs.durationSeconds / 3600 },
                            set: { config.cutoffs.durationSeconds = $0 * 3600 }
                        ),
                        in: 0.5...24,
                        step: 0.5
                    ) {
                        LabeledContent("Keep awake for", value: Format.duration(config.cutoffs.durationSeconds))
                    }
                }

                Toggle(isOn: $config.cutoffs.offTimeEnabled) {
                    Text("Off-time")
                    Text("Ends keep-awake at the next matching wall-clock time.")
                }
                if config.cutoffs.offTimeEnabled {
                    DatePicker(
                        "Sleep at",
                        selection: hmBinding($config.cutoffs.offTime),
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Time")
            } footer: {
                if state.isArmed {
                    Text("Changes apply immediately, including to the current session.")
                }
            }

            Section {
                Toggle(isOn: $config.behavior.sleepOnCutoff) {
                    Text("Request sleep at cutoff")
                    Text("With the lid closed, Lidless first requests and verifies normal sleep, then asks macOS to sleep. Hardware behavior still requires independent verification.")
                }
                Toggle(isOn: $config.behavior.notifyOnStateChanges) {
                    Text("Notify on arm, disarm & cutoff")
                }
                Toggle(isOn: $config.behavior.playCutoffSound) {
                    Text("Play sound at cutoff")
                }
            } header: {
                Text("On cutoff")
            }

            Section {
                Toggle(isOn: $config.behavior.lowPowerModeWhileArmed) {
                    Text("Low Power Mode while armed")
                    Text("Stretches the battery overnight; your previous power mode is restored on disarm.")
                }
                Toggle(isOn: $config.behavior.tcpKeepAliveWhileArmed) {
                    Text("Keep network alive")
                    Text("For SSH/screen-sharing into the closed MacBook: enforces tcpkeepalive so remote connections survive; restored on disarm.")
                }
                Toggle(isOn: $config.behavior.countdownInMenuBar) {
                    Text("Show countdown in menu bar")
                }
            } header: {
                Text("While armed")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Cutoffs")
        .background(Theme.canvas)
        .animation(reduceMotion ? nil : Theme.quickTransition, value: config.cutoffs)
    }

    private func hmBinding(_ source: Binding<HMTime>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let components = DateComponents(hour: source.wrappedValue.hour, minute: source.wrappedValue.minute)
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                source.wrappedValue = HMTime(hour: components.hour ?? 7, minute: components.minute ?? 0)
            }
        )
    }
}
