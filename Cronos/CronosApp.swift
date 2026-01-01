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

        Window("New Job", id: "add-job") {
            AddJobView()
                .environmentObject(jobManager)
        }
        .windowResizability(.contentSize)

        Window("Edit Job", id: "edit-job") {
            EditJobWindow()
                .environmentObject(jobManager)
        }
        .windowResizability(.contentSize)

        Window("Logs", id: "logs") {
            LogViewerWindow()
                .environmentObject(jobManager)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
