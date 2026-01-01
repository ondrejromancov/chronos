import SwiftUI

struct LogViewerView: View {
    let job: Job
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.dismiss) var dismiss
    @State private var stdout = ""
    @State private var stderr = ""
    @State private var selectedTab = 0
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Logs: \(job.name)")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    Task { await loadLogs() }
                }
                Button("Done") {
                    jobManager.selectedJobForLogs = nil
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                HStack {
                    Text("stdout")
                    if !stdout.isEmpty && stdout != "(empty)" {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                }
                .tag(0)

                HStack {
                    Text("stderr")
                    if !stderr.isEmpty && stderr != "(empty)" {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                    }
                }
                .tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Log content
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    Text(selectedTab == 0 ? stdout : stderr)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(width: 600, height: 400)
        .task {
            await loadLogs()
        }
    }

    private func loadLogs() async {
        isLoading = true
        let logs = await jobManager.readLog(for: job)
        stdout = logs.stdout.isEmpty ? "(empty)" : logs.stdout
        stderr = logs.stderr.isEmpty ? "(empty)" : logs.stderr
        isLoading = false
    }
}
