import Foundation

struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var command: String
    var workingDirectory: String
    var schedule: Schedule
    var isEnabled: Bool
    var lastRun: Date?
    var lastRunSuccessful: Bool?

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String,
        schedule: Schedule,
        isEnabled: Bool = true,
        lastRun: Date? = nil,
        lastRunSuccessful: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.lastRun = lastRun
        self.lastRunSuccessful = lastRunSuccessful
    }
}
