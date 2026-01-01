import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Cronos")
                        .font(.system(.headline, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    HoverButton(systemImage: "plus", help: "Add new job") {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "add-job")
                    }
                }
                .padding(.horizontal, LayoutConstants.horizontalMargin)
                .padding(.vertical, LayoutConstants.verticalMargin)

                // Search field (only show if there are jobs)
                if !jobManager.jobs.isEmpty {
                    SearchField(query: $jobManager.searchQuery, isFocused: $isSearchFocused)
                        .padding(.horizontal, LayoutConstants.horizontalMargin)
                        .padding(.bottom, 8)
                }

                // Job list
                if jobManager.jobs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.tertiary)
                        Text("No jobs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Add Job") {
                            NSApp.activate(ignoringOtherApps: true)
                            openWindow(id: "add-job")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else if jobManager.filteredJobs.isEmpty {
                    // Empty search results
                    VStack(spacing: 8) {
                        Text("No matching jobs")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Clear search") {
                            jobManager.clearSearch()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    JobListView()
                }

                // Footer
                HStack(spacing: 16) {
                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Settings")

                    Spacer()

                    HoverButton(systemImage: "power", iconSize: 11, help: "Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding(.horizontal, LayoutConstants.horizontalMargin)
                .padding(.vertical, LayoutConstants.verticalMargin)
            }
        }
        .frame(width: LayoutConstants.popupWidth)
        .onAppear {
            // Auto-focus search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onChange(of: jobManager.searchQuery) { _, _ in
            // Select first result when search changes
            jobManager.selectedJobId = jobManager.filteredJobs.first?.id
        }
        .onKeyPress(.downArrow) {
            isSearchFocused = false
            jobManager.selectNextJob()
            return .handled
        }
        .onKeyPress(.upArrow) {
            isSearchFocused = false
            jobManager.selectPreviousJob()
            return .handled
        }
        .onKeyPress(.return) {
            jobManager.toggleSelectedJobExpansion()
            return .handled
        }
        .onKeyPress(.escape) {
            if !jobManager.searchQuery.isEmpty {
                jobManager.clearSearch()
                return .handled
            }
            // Close the menu bar panel
            NSApp.keyWindow?.close()
            return .handled
        }
    }
}
