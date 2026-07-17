import SwiftUI
import LidlessCore

/// Dry-run controls (visible only with `--simulate`): drive battery, power,
/// and thermal inputs through the real arming flow, engine, and UI.
struct SimulatorPane: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let simulation = state.simulation {
            SimulatorControls(simulation: simulation)
        } else {
            ContentUnavailableView(
                "Simulation is off",
                systemImage: "slider.horizontal.3",
                description: Text("Relaunch Lidless with --simulate to use the simulator.")
            )
        }
    }
}

private struct SimulatorControls: View {
    @Bindable var simulation: SimulationController

    var body: some View {
        Form {
            Section {
                Banner(
                    kind: .info,
                    message: "Everything below feeds the real cutoff engine. No system power settings are touched in simulation."
                ) { EmptyView() }
            }

            Section("Battery") {
                LabeledContent("Charge: \(Int(simulation.batteryPercent))%") {
                    Slider(value: $simulation.batteryPercent, in: 0...100, step: 1)
                        .frame(maxWidth: 260)
                }
                Toggle("On battery power", isOn: $simulation.onBattery)
                Toggle("Charging", isOn: $simulation.charging)
                LabeledContent("Drain rate: \(String(format: "%.1f", simulation.drainPerHour))%/hr") {
                    Slider(value: $simulation.drainPerHour, in: 0...40, step: 0.5)
                        .frame(maxWidth: 260)
                }
                LabeledContent("Time scale: \(Int(simulation.timeScale))×") {
                    Slider(value: $simulation.timeScale, in: 1...600, step: 1)
                        .frame(maxWidth: 260)
                }
            }

            Section("Thermals") {
                Stepper(value: $simulation.thermalWarningLevel, in: 0...3) {
                    LabeledContent("Thermal warning level", value: "\(simulation.thermalWarningLevel)")
                }
                LabeledContent("CPU speed limit: \(simulation.cpuSpeedLimit)%") {
                    Slider(
                        value: Binding(
                            get: { Double(simulation.cpuSpeedLimit) },
                            set: { simulation.cpuSpeedLimit = Int($0) }
                        ),
                        in: 10...100,
                        step: 5
                    )
                    .frame(maxWidth: 260)
                }
                Picker("Process thermal state", selection: $simulation.processLevel) {
                    Text("Nominal").tag(ProcessThermalLevel.nominal)
                    Text("Fair").tag(ProcessThermalLevel.fair)
                    Text("Serious").tag(ProcessThermalLevel.serious)
                    Text("Critical").tag(ProcessThermalLevel.critical)
                }
            }

            Section("Machine") {
                Toggle("Lid closed", isOn: $simulation.lidClosed)
            }

            Section("Simulated helper log") {
                if simulation.log.isEmpty {
                    Text("Actions appear here as the app drives the fake helper.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(simulation.log.enumerated().reversed()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.caption.monospaced())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 160)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Simulator")
    }
}
