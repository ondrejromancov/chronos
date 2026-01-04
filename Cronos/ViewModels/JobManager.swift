import Foundation
import SwiftUI

@MainActor
class JobManager: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var runningJobIds: Set<UUID> = []
    @Published var editingJob: Job?
    @Published var selectedJob: Job?
    @Published var selectedJobForLogs: Job?
    @Published var selectedJobForHistory: Job?
    @Published var expandedJobId: UUID?
    @Published var errorMessage: String?

    // MARK: - Search & Keyboard Navigation

    @Published var selectedJobId: UUID?
    @Published var searchQuery: String = ""

    /// Filtered jobs based on search query
    var filteredJobs: [Job] {
        guard !searchQuery.isEmpty else { return jobs }
        let query = searchQuery.lowercased()
        return jobs.filter {
            $0.name.lowercased().contains(query) ||
            $0.command.lowercased().contains(query) ||
            ($0.claudePrompt ?? "").lowercased().contains(query)
        }
    }

    /// Live output data for currently running jobs
    @Published private(set) var liveOutputs: [UUID: LiveOutput] = [:]

    struct LiveOutput {
        var stdout: String = ""
        var stderr: String = ""
        var startedAt: Date
        var runId: UUID
    }

    private let store = JobStore()
    private let runner = JobRunner()
    private var scheduler: JobScheduler?

    // MARK: - File Watching (nonisolated for thread-safe dispatch source access)
    private nonisolated(unsafe) var fileMonitor: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var fileDescriptor: Int32 = -1

    init() {
        Task {
            await loadJobs()
            setupScheduler()
            setupFileWatcher()
            // Request notification permission
            _ = await NotificationService.shared.requestPermission()
        }
    }

    deinit {
        fileMonitor?.cancel()
    }

    // MARK: - File Watching

    private func setupFileWatcher() {
        let jobsFilePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronos/jobs.json").path

        // Open file descriptor for monitoring
        fileDescriptor = open(jobsFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            // File might not exist yet, which is fine
            return
        }

        // Create dispatch source to monitor file changes
        fileMonitor = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        fileMonitor?.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleFileChange()
            }
        }

        fileMonitor?.setCancelHandler { [fileDescriptor] in
            if fileDescriptor >= 0 {
                close(fileDescriptor)
            }
        }

        fileMonitor?.resume()
    }

    private func handleFileChange() async {
        // Reload jobs from disk
        await loadJobs()
        // Reschedule all jobs
        scheduler?.reschedule(jobs: jobs)
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
        // Clear selection if deleting selected job
        if selectedJobId == job.id {
            selectedJobId = nil
        }
        if selectedJob?.id == job.id {
            selectedJob = nil
        }
        jobs.removeAll { $0.id == job.id }
        // Clean up both legacy logs and new run history
        await store.deleteLog(for: job.id)
        try? await store.deleteRunsFor(jobId: job.id)
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

        // Create a new run record
        var run: LogRun?
        do {
            run = try await store.createRun(for: job.id)
        } catch {
            errorMessage = "Failed to create log run: \(error.localizedDescription)"
        }

        // Initialize live output for this job
        if let run = run {
            liveOutputs[job.id] = LiveOutput(
                stdout: "",
                stderr: "",
                startedAt: run.startedAt,
                runId: run.id
            )
        }

        do {
            // Use the new run-based log files if available, otherwise fall back to legacy
            let logFiles: (stdout: URL, stderr: URL)
            if let run = run {
                logFiles = await store.logFilesForRun(run.id)
            } else {
                logFiles = await store.logFiles(for: job.id)
            }

            let shell = UserDefaults.standard.string(forKey: "shell") ?? Shell.zsh.rawValue
            let success = try await runner.run(
                command: job.effectiveCommand,
                workingDirectory: job.workingDirectory,
                shell: shell,
                stdoutFile: logFiles.stdout,
                stderrFile: logFiles.stderr,
                onStdout: { [weak self] text in
                    Task { @MainActor [weak self] in
                        self?.liveOutputs[job.id]?.stdout.append(text)
                    }
                },
                onStderr: { [weak self] text in
                    Task { @MainActor [weak self] in
                        self?.liveOutputs[job.id]?.stderr.append(text)
                    }
                }
            )

            // Complete the run record
            if let run = run {
                try? await store.completeRun(run, exitCode: success ? 0 : 1, success: success)
            }

            // Update job with last run info
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].lastRun = Date()
                jobs[index].lastRunSuccessful = success
                await saveJobs()
            }

            // Send notification with output preview
            let output = liveOutputs[job.id]?.stdout ?? ""
            if success {
                await NotificationService.shared.sendJobSucceededNotification(jobId: job.id, jobName: job.name, output: output)
            } else {
                let errorOutput = liveOutputs[job.id]?.stderr ?? output
                await NotificationService.shared.sendJobFailedNotification(jobId: job.id, jobName: job.name, output: errorOutput)
            }
        } catch {
            errorMessage = "Failed to run job '\(job.name)': \(error.localizedDescription)"

            // Complete the run as failed
            if let run = run {
                try? await store.completeRun(run, exitCode: -1, success: false)
            }

            // Still mark job as failed
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index].lastRun = Date()
                jobs[index].lastRunSuccessful = false
                await saveJobs()
            }

            // Send notification on error
            let errorOutput = liveOutputs[job.id]?.stderr ?? liveOutputs[job.id]?.stdout
            await NotificationService.shared.sendJobFailedNotification(jobId: job.id, jobName: job.name, output: errorOutput)
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

    // MARK: - Live Output

    /// Get live stdout for a running job
    func liveStdout(for job: Job) -> String {
        liveOutputs[job.id]?.stdout ?? ""
    }

    /// Get live stderr for a running job
    func liveStderr(for job: Job) -> String {
        liveOutputs[job.id]?.stderr ?? ""
    }

    /// Get when the current run started
    func currentRunStartTime(for job: Job) -> Date? {
        liveOutputs[job.id]?.startedAt
    }

    // MARK: - Run History

    /// Load all runs for a job (newest first)
    func loadRuns(for jobId: UUID) async -> [LogRun] {
        (try? await store.runsFor(jobId: jobId)) ?? []
    }

    /// Get the latest run for a job
    func latestRun(for job: Job) async -> LogRun? {
        try? await store.latestRun(for: job.id)
    }

    /// Read log content for a specific run
    func readLogForRun(_ runId: UUID) async -> (stdout: String, stderr: String) {
        await store.readLogForRun(runId)
    }

    // MARK: - Scheduler

    private func setupScheduler() {
        scheduler = JobScheduler(
            onTrigger: { [weak self] jobId in
                guard let self = self else { return }

                Task { @MainActor in
                    guard let job = self.jobs.first(where: { $0.id == jobId }) else { return }
                    await self.runJob(job)
                }
            },
            jobProvider: { [weak self] in
                self?.jobs ?? []
            }
        )
        scheduler?.reschedule(jobs: jobs)
    }

    // MARK: - Keyboard Navigation

    func selectNextJob() {
        let list = filteredJobs
        guard !list.isEmpty else { return }

        if let currentId = selectedJobId,
           let currentIndex = list.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = min(currentIndex + 1, list.count - 1)
            selectedJobId = list[nextIndex].id
        } else {
            selectedJobId = list.first?.id
        }
    }

    func selectPreviousJob() {
        let list = filteredJobs
        guard !list.isEmpty else { return }

        if let currentId = selectedJobId,
           let currentIndex = list.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectedJobId = list[prevIndex].id
        } else {
            selectedJobId = list.last?.id
        }
    }

    func toggleSelectedJobExpansion() {
        guard let id = selectedJobId else { return }
        // Toggle selection for popover (using selectedJob)
        if selectedJob?.id == id {
            selectedJob = nil
        } else if let job = filteredJobs.first(where: { $0.id == id }) {
            selectedJob = job
        }
    }

    func clearSearch() {
        searchQuery = ""
    }
}
