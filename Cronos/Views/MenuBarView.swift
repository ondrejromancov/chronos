import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cronos")
                    .font(.headline)
                Spacer()
                Button(action: { openWindow(id: "add-job") }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add new job")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Job list
            if jobManager.jobs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No jobs scheduled")
                        .foregroundStyle(.secondary)
                    Button("Add Job") {
                        openWindow(id: "add-job")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                JobListView()
            }

            Divider()

            // Footer
            HStack {
                SettingsLink {
                    Text("Settings...")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }
}
