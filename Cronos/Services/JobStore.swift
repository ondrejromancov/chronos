import Foundation

actor JobStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var cronosDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".cronos")
    }

    private var jobsFile: URL {
        cronosDirectory.appendingPathComponent("jobs.json")
    }

    var logsDirectory: URL {
        cronosDirectory.appendingPathComponent("logs")
    }

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Ensures ~/.cronos/ and ~/.cronos/logs/ exist
    func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(
            at: cronosDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Load all jobs from disk
    func loadJobs() throws -> [Job] {
        try ensureDirectoriesExist()

        guard fileManager.fileExists(atPath: jobsFile.path) else {
            return []
        }

        let data = try Data(contentsOf: jobsFile)
        return try decoder.decode([Job].self, from: data)
    }

    /// Save all jobs to disk
    func saveJobs(_ jobs: [Job]) throws {
        try ensureDirectoriesExist()
        let data = try encoder.encode(jobs)
        try data.write(to: jobsFile, options: .atomic)
    }

    /// Get log file URLs for a job
    func logFiles(for jobId: UUID) -> (stdout: URL, stderr: URL) {
        let stdout = logsDirectory.appendingPathComponent("\(jobId.uuidString).log")
        let stderr = logsDirectory.appendingPathComponent("\(jobId.uuidString).err")
        return (stdout, stderr)
    }

    /// Read log content for a job
    func readLog(for jobId: UUID) -> (stdout: String, stderr: String) {
        let files = logFiles(for: jobId)
        let stdout = (try? String(contentsOf: files.stdout, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: files.stderr, encoding: .utf8)) ?? ""
        return (stdout, stderr)
    }

    /// Delete log files for a job
    func deleteLog(for jobId: UUID) {
        let files = logFiles(for: jobId)
        try? fileManager.removeItem(at: files.stdout)
        try? fileManager.removeItem(at: files.stderr)
    }
}
