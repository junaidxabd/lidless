import SwiftUI
import LidlessCore

/// Recurring keep-awake windows ("weeknights 11 PM – 7 AM").
struct SchedulesPane: View {
    @Environment(AppState.self) private var state
    @State private var editingWindow: ScheduleWindow?
    @State private var isCreating = false

    var body: some View {
        @Bindable var config = state.config
        Form {
            Section {
                Toggle(isOn: $config.scheduleAutomationEnabled) {
                    Text("Arm automatically on schedule")
                    Text("Lidless arms when a window starts and restores normal sleep when it ends. Disarming during a window skips just that occurrence. Requires “Launch at login.”")
                }
            } footer: {
                Text("Lidless also registers a system wake just before each window, so a sleeping MacBook can wake up and arm itself (best effort).")
            }

            Section("Windows") {
                if config.schedules.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: Theme.s2) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2)
                                .foregroundStyle(.tertiary)
                            Text("No schedule windows yet")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, Theme.s4)
                        Spacer()
                    }
                } else {
                    ForEach($config.schedules) { $window in
                        HStack(spacing: Theme.s3) {
                            Toggle("", isOn: $window.enabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.weekdaysSummary(window.weekdays))
                                    .font(.body.weight(.medium))
                                Text("\(Format.clock(window.start)) – \(Format.clock(window.end))\(window.wrapsMidnight ? " (next day)" : "")")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                editingWindow = window
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                config.schedules.removeAll { $0.id == window.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .opacity(window.enabled ? 1 : 0.55)
                    }
                }

                Button {
                    isCreating = true
                } label: {
                    Label("Add Window", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("Schedules")
        .sheet(item: $editingWindow) { window in
            ScheduleWindowEditor(window: window) { updated in
                if let index = state.config.schedules.firstIndex(where: { $0.id == updated.id }) {
                    state.config.schedules[index] = updated
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            ScheduleWindowEditor(window: ScheduleWindow.weeknights()) { created in
                state.config.schedules.append(created)
            }
        }
    }

    static func weekdaysSummary(_ weekdays: Set<Int>) -> String {
        let names = Calendar.current.shortWeekdaySymbols // Sun-first
        if weekdays == Set(1...7) { return "Every day" }
        if weekdays == [1, 2, 3, 4, 5] { return "Sun – Thu nights" }
        if weekdays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdays == [1, 7] { return "Weekends" }
        let sorted = weekdays.sorted()
        return sorted.compactMap { index in
            names.indices.contains(index - 1) ? names[index - 1] : nil
        }.joined(separator: " ")
    }
}

// MARK: - Editor sheet

struct ScheduleWindowEditor: View {
    @State var window: ScheduleWindow
    let onSave: (ScheduleWindow) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            Text("Schedule Window")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("Repeats on")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                WeekdayPicker(selection: $window.weekdays)
                Text("Days refer to when the window starts — a Friday 11 PM window runs into Saturday morning.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: Theme.s4) {
                DatePicker("Starts", selection: hmBinding($window.start), displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: hmBinding($window.end), displayedComponents: .hourAndMinute)
            }
            if window.wrapsMidnight {
                Label("Ends the next day", systemImage: "moon.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave(window)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(window.weekdays.isEmpty)
            }
        }
        .padding(Theme.s6)
        .frame(width: 420)
    }

    private func hmBinding(_ source: Binding<HMTime>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let components = DateComponents(hour: source.wrappedValue.hour, minute: source.wrappedValue.minute)
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                source.wrappedValue = HMTime(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }
        )
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: Theme.s1) {
            ForEach(1...7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.callout.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(
                            isOn ? AnyShapeStyle(Theme.armedGradient) : AnyShapeStyle(.quaternary.opacity(0.5)),
                            in: Circle()
                        )
                        .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(isOn ? [.isSelected] : [])
            }
        }
        .animation(Theme.springQuick, value: selection)
    }
}
