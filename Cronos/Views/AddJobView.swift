import SwiftUI

struct AddJobView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.dismiss) var dismiss

    let editing: Job?

    @State private var name = ""
    @State private var command = ""
    @State private var workingDirectory = "~"
    @State private var scheduleType: ScheduleType = .daily
    @State private var hour = 9
    @State private var minute = 0
    @State private var weekday = 2 // Monday

    enum ScheduleType: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
    }

    init(editing: Job? = nil) {
        self.editing = editing
    }

    var body: some View {
        VStack(spacing: 0) {
            // Form
            Form {
                Section {
                    TextField("Name", text: $name)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        TextEditor(text: $command)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.primary.opacity(HoverOpacity.subtle))
                            .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.buttonCornerRadius))
                    }

                    HStack {
                        TextField("Working Directory", text: $workingDirectory)
                            .font(.system(.body, design: .monospaced))
                        Button(action: selectDirectory) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section {
                    Picker("Schedule", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Time")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        Text(":")
                            .foregroundStyle(.tertiary)
                        Picker("", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }

                    if scheduleType == .weekly {
                        Picker("Day", selection: $weekday) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // Buttons
            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                .foregroundStyle(.secondary)

                Spacer()

                Button(editing == nil ? "Add" : "Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()
        }
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if let job = editing {
                name = job.name
                command = job.command
                workingDirectory = job.workingDirectory

                switch job.schedule {
                case .daily(let h, let m):
                    scheduleType = .daily
                    hour = h
                    minute = m
                case .weekly(let w, let h, let m):
                    scheduleType = .weekly
                    weekday = w
                    hour = h
                    minute = m
                }
            }
        }
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }

    private func save() {
        let schedule: Schedule = scheduleType == .daily
            ? .daily(hour: hour, minute: minute)
            : .weekly(weekday: weekday, hour: hour, minute: minute)

        if let existing = editing {
            var updated = existing
            updated.name = name
            updated.command = command
            updated.workingDirectory = workingDirectory
            updated.schedule = schedule
            Task {
                await jobManager.updateJob(updated)
            }
        } else {
            let job = Job(
                name: name,
                command: command,
                workingDirectory: workingDirectory,
                schedule: schedule
            )
            Task {
                await jobManager.addJob(job)
            }
        }

        closeWindow()
    }

    private func closeWindow() {
        if editing != nil {
            jobManager.editingJob = nil
        }
        dismiss()
    }
}
