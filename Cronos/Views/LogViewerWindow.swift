import SwiftUI

struct LogViewerWindow: View {
    @EnvironmentObject var jobManager: JobManager

    var body: some View {
        if let job = jobManager.selectedJobForLogs {
            LogViewerView(job: job)
                .environmentObject(jobManager)
        } else {
            ContentUnavailableView(
                "No Job Selected",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Select a job to view logs from the menu bar.")
            )
            .frame(width: 500, height: 300)
        }
    }
}
