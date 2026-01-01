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
            // Header
            HStack {
                Text(editing == nil ? "New Job" : "Edit Job")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $command)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    HStack {
                        TextField("Working Directory", text: $workingDirectory)
                            .textFieldStyle(.roundedBorder)
                        Button(action: selectDirectory) {
                            Image(systemName: "folder")
                        }
                    }
                }

                Section("Schedule") {
                    Picker("", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    HStack {
                        Text("Time:")
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 60)
                        Text(":")
                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
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

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(editing == nil ? "Add" : "Save") {
                    save()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
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
