import SwiftUI

struct JobRowView: View {
    let job: Job
    @EnvironmentObject var jobManager: JobManager
    @State private var isHovered = false
    @State private var lastLogLine: String = ""

    private var isRunning: Bool {
        jobManager.isRunning(job)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main row
            HStack(spacing: 10) {
                // Status dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .opacity(isRunning ? 1 : 0.9)
                    .animation(
                        isRunning
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: isRunning
                    )

                // Job name
                Text(job.name)
                    .lineLimit(1)
                    .foregroundStyle(job.isEnabled ? .primary : .secondary)

                Spacer()

                // Status text
                Text(statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            // Last log line preview
            if !lastLogPreview.isEmpty {
                Text(lastLogPreview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, LayoutConstants.horizontalMargin)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: LayoutConstants.cellCornerRadius)
                .fill(Color.primary.opacity(isHovered ? HoverOpacity.standard : 0))
        )
        .animation(.easeInOut(duration: AnimationDurations.fast), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadLastLogLine()
        }
        .onChange(of: isRunning) { wasRunning, nowRunning in
            if wasRunning && !nowRunning {
                Task { await loadLastLogLine() }
            }
        }
        .onChange(of: jobManager.liveOutputs[job.id]?.stdout) { _, _ in
            updateLiveLogLine()
        }
    }

    private var lastLogPreview: String {
        if isRunning {
            // Show live output
            let liveStdout = jobManager.liveStdout(for: job)
            if let lastLine = liveStdout.split(separator: "\n").last {
                return String(lastLine)
            }
            return ""
        }
        return lastLogLine
    }

    private func updateLiveLogLine() {
        let liveStdout = jobManager.liveStdout(for: job)
        if let lastLine = liveStdout.split(separator: "\n").last {
            lastLogLine = String(lastLine)
        }
    }

    private func loadLastLogLine() async {
        // Try to load from the latest run
        if let run = await jobManager.latestRun(for: job) {
            let logs = await jobManager.readLogForRun(run.id)
            let output = logs.stderr.isEmpty ? logs.stdout : logs.stderr
            if let lastLine = output.split(separator: "\n").last {
                lastLogLine = String(lastLine)
            } else {
                lastLogLine = ""
            }
        } else {
            // Fall back to legacy logs
            let logs = await jobManager.readLog(for: job)
            let output = logs.stderr.isEmpty ? logs.stdout : logs.stderr
            if let lastLine = output.split(separator: "\n").last {
                lastLogLine = String(lastLine)
            } else {
                lastLogLine = ""
            }
        }
    }

    private var statusColor: Color {
        if jobManager.isRunning(job) {
            return .blue
        } else if !job.isEnabled {
            return .secondary.opacity(0.5)
        } else {
            return .green
        }
    }

    private var statusText: String {
        if jobManager.isRunning(job) {
            return "running"
        }
        guard job.isEnabled else { return "disabled" }

        let nextRun = job.schedule.nextRun()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: nextRun, relativeTo: Date())
    }
}
