import Foundation

public enum ClipboardAge {
    public static func label(createdAt: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(createdAt)))
        if seconds < 60 { return seconds == 1 ? "1 sec" : "\(seconds) secs" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }
}
