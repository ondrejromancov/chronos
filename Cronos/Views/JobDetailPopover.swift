import SwiftUI

struct JobDetailPopover: View {
    let job: Job
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text(job.name)
                .font(.headline)

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(label: "Command") {
                    Text(job.command)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                DetailRow(label: "Working Dir") {
                    Text(job.workingDirectory)
                        .font(.caption)
                }

                DetailRow(label: "Schedule") {
                    Text(job.schedule.displayString)
                        .font(.caption)
                }

                if let lastRun = job.lastRun {
                    DetailRow(label: "Last run") {
                        HStack(spacing: 4) {
                            Text("\(lastRun, style: .relative) ago")
                            if let success = job.lastRunSuccessful {
                                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(success ? .green : .red)
                            }
                        }
                        .font(.caption)
                    }
                }

                DetailRow(label: "Next run") {
                    Text(job.isEnabled ? job.schedule.nextRun().formatted(date: .abbreviated, time: .shortened) : "Disabled")
                        .font(.caption)
                        .foregroundStyle(job.isEnabled ? .primary : .secondary)
                }
            }

            Divider()

            // Actions
            HStack(spacing: 8) {
                Button("View Logs") {
                    jobManager.selectedJobForLogs = job
                    openWindow(id: "logs")
                }

                Button("Run Now") {
                    Task {
                        dismiss()
                        await jobManager.runJob(job)
                    }
                }
                .disabled(jobManager.isRunning(job))

                Button("Edit") {
                    jobManager.editingJob = job
                    openWindow(id: "edit-job")
                }
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                Button(job.isEnabled ? "Disable" : "Enable") {
                    Task {
                        await jobManager.toggleJob(job)
                        dismiss()
                    }
                }

                Button("Delete", role: .destructive) {
                    showingDeleteConfirm = true
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(width: 300)
        .confirmationDialog("Delete '\(job.name)'?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await jobManager.deleteJob(job)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

struct DetailRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content
        }
    }
}
