import Foundation

class JobScheduler {
    private var timers: [UUID: Timer] = [:]
    private let onTrigger: (UUID) -> Void

    init(onTrigger: @escaping (UUID) -> Void) {
        self.onTrigger = onTrigger
    }

    /// Reschedule all jobs (call after any job change)
    func reschedule(jobs: [Job]) {
        // Cancel all existing timers
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()

        // Schedule enabled jobs
        for job in jobs where job.isEnabled {
            scheduleNext(job: job)
        }
    }

    private func scheduleNext(job: Job) {
        let nextRun = job.schedule.nextRun()
        let interval = nextRun.timeIntervalSinceNow

        guard interval > 0 else {
            // Schedule for next occurrence if somehow in the past
            let futureRun = job.schedule.nextRun(after: Date().addingTimeInterval(1))
            scheduleTimer(for: job, at: futureRun)
            return
        }

        scheduleTimer(for: job, at: nextRun)
    }

    private func scheduleTimer(for job: Job, at fireDate: Date) {
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Trigger the job
            self.onTrigger(job.id)

            // Schedule the next occurrence
            DispatchQueue.main.async {
                self.scheduleNext(job: job)
            }
        }

        // Add to run loop on main thread with .common mode so it fires during menu interactions
        RunLoop.main.add(timer, forMode: .common)
        timers[job.id] = timer
    }

    func cancelJob(_ jobId: UUID) {
        timers[jobId]?.invalidate()
        timers.removeValue(forKey: jobId)
    }

    deinit {
        timers.values.forEach { $0.invalidate() }
    }
}
