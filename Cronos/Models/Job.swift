import Foundation

enum JobType: String, Codable, CaseIterable {
    case claude
    case customCommand
}

struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var schedule: Schedule
    var isEnabled: Bool
    var lastRun: Date?
    var lastRunSuccessful: Bool?

    // Claude-specific fields
    var jobType: JobType
    var claudePrompt: String?
    var contextDirectory: String?

    init(
        id: UUID = UUID(),
        name: String,
        command: String = "",
        workingDirectory: String,
        schedule: Schedule,
        isEnabled: Bool = true,
        lastRun: Date? = nil,
        lastRunSuccessful: Bool? = nil,
        jobType: JobType = .claude,
        claudePrompt: String? = nil,
        contextDirectory: String? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.lastRun = lastRun
        self.lastRunSuccessful = lastRunSuccessful
        self.jobType = jobType
        self.claudePrompt = claudePrompt
        self.contextDirectory = contextDirectory
    }

    /// The command to actually execute, generated from job type and fields
    var effectiveCommand: String {
        switch jobType {
        case .claude:
            let prompt = claudePrompt ?? ""
            let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\\''")
            var cmd = "claude -p '\(escapedPrompt)'"
            if let dir = contextDirectory, !dir.isEmpty {
                // Expand tilde before quoting to ensure shell expansion works
                let expandedDir = (dir as NSString).expandingTildeInPath
                let escapedDir = expandedDir.replacingOccurrences(of: "'", with: "'\\''")
                cmd += " '\(escapedDir)'"
            }
            return cmd
        case .customCommand:
            return command
        }
    }

    // Custom decoder for backwards compatibility with existing jobs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
        schedule = try container.decode(Schedule.self, forKey: .schedule)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        lastRun = try container.decodeIfPresent(Date.self, forKey: .lastRun)
        lastRunSuccessful = try container.decodeIfPresent(Bool.self, forKey: .lastRunSuccessful)

        // New fields with defaults for migration
        jobType = try container.decodeIfPresent(JobType.self, forKey: .jobType) ?? .customCommand
        claudePrompt = try container.decodeIfPresent(String.self, forKey: .claudePrompt)
        contextDirectory = try container.decodeIfPresent(String.self, forKey: .contextDirectory)
    }
}
