import SwiftUI

struct JobListView: View {
    @EnvironmentObject var jobManager: JobManager

    private func isKeyboardSelected(_ job: Job) -> Bool {
        jobManager.selectedJobId == job.id
    }

    private func isPopoverOpen(_ job: Job) -> Bool {
        jobManager.selectedJob?.id == job.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: LayoutConstants.itemSpacing) {
                    ForEach(jobManager.filteredJobs) { job in
                        JobRowView(job: job)
                            .id(job.id)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: LayoutConstants.cellCornerRadius)
                                    .fill(backgroundColor(for: job))
                            )
                            .onTapGesture {
                                jobManager.selectedJobId = job.id
                                if jobManager.selectedJob?.id == job.id {
                                    jobManager.selectedJob = nil
                                } else {
                                    jobManager.selectedJob = job
                                }
                            }
                            .popover(
                                isPresented: Binding(
                                    get: { jobManager.selectedJob?.id == job.id },
                                    set: { if !$0 { jobManager.selectedJob = nil } }
                                ),
                                arrowEdge: .trailing
                            ) {
                                JobDetailSidebar(job: job)
                                    .frame(width: 180)
                            }
                    }
                }
            }
            .onChange(of: jobManager.selectedJobId) { _, newId in
                if let id = newId {
                    withAnimation(.easeInOut(duration: AnimationDurations.fast)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .onChange(of: jobManager.filteredJobs) { _, newFiltered in
                // Ensure selection is still valid after filtering
                if let selectedId = jobManager.selectedJobId,
                   !newFiltered.contains(where: { $0.id == selectedId }) {
                    jobManager.selectedJobId = newFiltered.first?.id
                }
                // Close popover if job is filtered out
                if let popoverId = jobManager.selectedJob?.id,
                   !newFiltered.contains(where: { $0.id == popoverId }) {
                    jobManager.selectedJob = nil
                }
            }
        }
        .frame(maxHeight: 400)
    }

    private func backgroundColor(for job: Job) -> Color {
        if isPopoverOpen(job) {
            return Color.accentColor.opacity(HoverOpacity.selected)
        } else if isKeyboardSelected(job) {
            return Color.accentColor.opacity(HoverOpacity.standard)
        } else {
            return Color.clear
        }
    }
}
