import Foundation

enum Schedule: Codable, Equatable {
    case daily(hour: Int, minute: Int)
    case weekly(weekday: Int, hour: Int, minute: Int) // weekday: 1=Sun, 7=Sat

    /// Returns the next scheduled run time after the given date
    func nextRun(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()

        switch self {
        case .daily(let hour, let minute):
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let nextRun = calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime
            ) else {
                return date
            }
            return nextRun

        case .weekly(let weekday, let hour, let minute):
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let nextRun = calendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime
            ) else {
                return date
            }
            return nextRun
        }
    }

    /// Human-readable description
    var displayString: String {
        switch self {
        case .daily(let hour, let minute):
            let timeString = String(format: "%d:%02d", hour, minute)
            return "Daily at \(timeString)"

        case .weekly(let weekday, let hour, let minute):
            let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let dayName = weekday >= 1 && weekday <= 7 ? days[weekday] : "Unknown"
            let timeString = String(format: "%d:%02d", hour, minute)
            return "\(dayName) at \(timeString)"
        }
    }
}
