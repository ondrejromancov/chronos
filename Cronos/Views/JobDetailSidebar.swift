import SwiftUI

struct JobDetailSidebar: View {
    let job: Job
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.openWindow) private var openWindow
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(job.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(job.schedule.displayString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    if let success = job.lastRunSuccessful {
                        Circle()
                            .fill(success ? Color.green : Color.red)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Menu items
            VStack(spacing: 2) {
                MenuRow(icon: "play.fill", label: "Run Now", disabled: jobManager.isRunning(job)) {
                    Task { await jobManager.runJob(job) }
                }

                MenuRow(icon: "pencil", label: "Edit") {
                    jobManager.editingJob = job
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "edit-job")
                }

                MenuRow(icon: "clock.arrow.circlepath", label: "Log History") {
                    jobManager.selectedJobForHistory = job
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "log-history")
                }
            }

            Divider()
                .padding(.vertical, 6)
                .padding(.horizontal, 12)

            VStack(spacing: 2) {
                MenuRow(
                    icon: job.isEnabled ? "pause.fill" : "play.fill",
                    label: job.isEnabled ? "Pause" : "Resume"
                ) {
                    Task { await jobManager.toggleJob(job) }
                }

                MenuRow(icon: "trash", label: "Delete", isDestructive: true) {
                    showingDeleteConfirm = true
                }
            }
            .padding(.bottom, 8)
        }
        .confirmationDialog("Delete '\(job.name)'?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await jobManager.deleteJob(job)
                    jobManager.selectedJob = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Menu Row Component

private struct MenuRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 16)
                    .foregroundStyle(isDestructive ? .red.opacity(0.8) : .secondary)

                Text(label)
                    .font(.system(.body))
                    .foregroundStyle(isDestructive ? .red.opacity(0.8) : .primary)

                Spacer()
            }
            .padding(.horizontal, LayoutConstants.horizontalMargin)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: LayoutConstants.buttonCornerRadius)
                    .fill(Color.primary.opacity(isHovered ? HoverOpacity.standard : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
        .animation(.easeInOut(duration: AnimationDurations.fast), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
