import SwiftUI

struct EditJobWindow: View {
    @EnvironmentObject var jobManager: JobManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        if let job = jobManager.editingJob {
            AddJobView(editing: job)
                .environmentObject(jobManager)
        } else {
            ContentUnavailableView(
                "No Job Selected",
                systemImage: "doc.questionmark",
                description: Text("Select a job to edit from the menu bar.")
            )
            .frame(width: 400, height: 300)
        }
    }
}
