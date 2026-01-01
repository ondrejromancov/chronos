import SwiftUI

struct InlineLogView: View {
    let job: Job
    @EnvironmentObject var jobManager: JobManager
    @State private var selectedTab: LogTab = .stdout
    @State private var logs: (stdout: String, stderr: String) = ("", "")
    @State private var latestRun: LogRun?
    @State private var isLoading = true
    @State private var scrollPosition: String?

    enum LogTab: String, CaseIterable {
        case stdout = "stdout"
        case stderr = "stderr"
    }

    private var isRunning: Bool {
        jobManager.isRunning(job)
    }

    private var currentStdout: String {
        if isRunning {
            return jobManager.liveStdout(for: job)
        }
        return logs.stdout
    }

    private var currentStderr: String {
        if isRunning {
            return jobManager.liveStderr(for: job)
        }
        return logs.stderr
    }

    private var displayedLog: String {
        switch selectedTab {
        case .stdout:
            return currentStdout
        case .stderr:
            return currentStderr
        }
    }

    private var runStartTime: Date? {
        if isRunning {
            return jobManager.currentRunStartTime(for: job)
        }
        return latestRun?.startedAt
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                // Tabs
                Picker("", selection: $selectedTab) {
                    ForEach(LogTab.allCases, id: \.self) { tab in
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                            if hasContent(for: tab) {
                                Circle()
                                    .fill(tab == .stderr ? Color.red : Color.green)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Spacer()

                // Timestamp
                if let startTime = runStartTime {
                    Text(formatTimestamp(startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // History button
                Button {
                    jobManager.selectedJobForHistory = job
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "log-history" }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        NSApp.sendAction(Selector(("openWindow:")), to: nil, from: "log-history")
                    }
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("View log history")
            }
            .padding(.horizontal, LayoutConstants.horizontalMargin)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(HoverOpacity.subtle))

            Divider()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    if displayedLog.isEmpty {
                        Text(isRunning ? "Waiting for output..." : "(empty)")
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        Text(displayedLog)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(selectedTab == .stderr ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .id("logContent")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .frame(height: 180)
                .background(
                    RoundedRectangle(cornerRadius: LayoutConstants.buttonCornerRadius)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
                )
                .onChange(of: displayedLog) { _, newValue in
                    // Smart auto-scroll: only scroll if we're near the bottom
                    // For simplicity, always scroll on new content while running
                    if isRunning {
                        withAnimation(.easeOut(duration: AnimationDurations.instant)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .task {
            await loadLogs()
        }
        .onChange(of: isRunning) { wasRunning, nowRunning in
            if wasRunning && !nowRunning {
                // Job finished, reload logs from disk
                Task {
                    await loadLogs()
                }
            }
        }
    }

    private func hasContent(for tab: LogTab) -> Bool {
        switch tab {
        case .stdout:
            return !currentStdout.isEmpty
        case .stderr:
            return !currentStderr.isEmpty
        }
    }

    private func loadLogs() async {
        isLoading = true
        defer { isLoading = false }

        // Try to load from the latest run first
        if let run = await jobManager.latestRun(for: job) {
            latestRun = run
            logs = await jobManager.readLogForRun(run.id)
        } else {
            // Fall back to legacy logs
            logs = await jobManager.readLog(for: job)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
