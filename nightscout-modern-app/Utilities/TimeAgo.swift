import Foundation

enum TimeAgo {
    /// Returns a localized relative time string in Portuguese.
    static func string(from date: Date) -> String {
        let diffMs = Date().timeIntervalSince(date) * 1000
        let diffMins = Int(diffMs / 60_000)

        if diffMins < 1  { return "agora" }
        if diffMins < 60 { return "há \(diffMins) min" }

        let diffHours = diffMins / 60
        if diffHours < 24 { return "há \(diffHours)h" }

        let diffDays = diffHours / 24
        return "há \(diffDays)d"
    }

    /// Returns a localized relative time string from a millisecond timestamp.
    static func string(fromMs ms: Double) -> String {
        string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    /// Check if data is stale (older than given minutes).
    static func isStale(_ date: Date, minutes: Int) -> Bool {
        Date().timeIntervalSince(date) > Double(minutes) * 60
    }
}
