import Foundation
import SwiftUI

@MainActor
class JobManager: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var runningJobIds: Set<UUID> = []
    @Published var showingAddJob = false
    @Published var editingJob: Job?
    @Published var selectedJob: Job?
    @Published var errorMessage: String?

    private let store = JobStore()
    private let runner = JobRunner()
    private var scheduler: JobScheduler?

    init() {
        Task {
            await loadJobs()
            setupScheduler()
        }
    }

    // MARK: - Job CRUD

    func loadJobs() async {
        do {
            jobs = try await store.loadJobs()
        } catch {
            errorMessage = "Failed to load jobs: \(error.localizedDescription)"
            jobs = []
        }
    }

    func addJob(_ job: Job) async {
        jobs.append(job)
        await saveJobs()
        scheduler?.reschedule(jobs: jobs)
    }

    func updateJob(_ job: Job) async {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index] = job
        await saveJobs()
        scheduler?.reschedule(jobs: jobs)
    }

    func deleteJob(_ job: Job) async {
        jobs.removeAll { $0.id == job.id }
        await store.deleteLog(for: job.id)
        await saveJobs()
        scheduler?.reschedule(jobs: jobs)
    }

    func toggleJob(_ job: Job) async {
        var updated = job
        updated.isEnabled.toggle()
        await updateJob(updated)
    }

    private func saveJobs() async {
        do {
            try await store.saveJobs(jobs)
        } catch {
            errorMessage = "Failed to save jobs: \(error.localizedDescription)"
        }
    }

    // MARK: - Job Execution

    func runJob(_ job: Job) async {
        guard !runningJobIds.contains(job.id) else {
            return // Skip if already running
        }

        runningJobIds.insert(job.id)

        do {
            let logFiles = await store.logFiles(for: job.id)
            let success = try await runner.run(
                command: job.command,
                workingDirectory: job.workingDirectory,
                stdoutFile: logFiles.stdout,
                stderrFile: logFiles.stderr
            )

            // Update job with last run info
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].lastRun = Date()
                jobs[index].lastRunSuccessful = success
                await saveJobs()
            }
        } catch {
            errorMessage = "Failed to run job '\(job.name)': \(error.localizedDescription)"

            // Still mark as failed
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].lastRun = Date()
                jobs[index].lastRunSuccessful = false
                await saveJobs()
            }
        }

        runningJobIds.remove(job.id)
    }

    func isRunning(_ job: Job) -> Bool {
        runningJobIds.contains(job.id)
    }

    // MARK: - Logs

    func readLog(for job: Job) async -> (stdout: String, stderr: String) {
        await store.readLog(for: job.id)
    }

    // MARK: - Scheduler

    private func setupScheduler() {
        scheduler = JobScheduler { [weak self] jobId in
            guard let self = self else { return }

            Task { @MainActor in
                guard let job = self.jobs.first(where: { $0.id == jobId }) else { return }
                await self.runJob(job)
            }
        }
        scheduler?.reschedule(jobs: jobs)
    }
}
