import SwiftUI

@main
struct CronosApp: App {
    @StateObject private var jobManager = JobManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(jobManager)
        } label: {
            Label("Cronos", systemImage: "clock.badge.checkmark")
                .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
