import Foundation

/// Week start used for display ordering. Teaching weeks always use a Monday anchor.
public enum WeekStartDay: String, Codable, CaseIterable, Sendable, Identifiable {
    case monday
    case sunday

    public var id: String { rawValue }

    public var firstWeekday: Int { self == .monday ? 2 : 1 }

    /// ISO weekday of the first column: 1 = Monday, 7 = Sunday.
    public var isoDayOfWeek: Int { self == .monday ? 1 : 7 }
}

public enum ScheduleCalendar {

    public static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Convert Foundation's Sunday-based weekday into ISO numbering (1 = Monday ... 7 = Sunday).
    public static func isoDayOfWeek(_ date: Date, calendar: Calendar = .current) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7 + 1
    }

    /// Monday 00:00 of the teaching week containing `date`.
    public static func startOfTeachingWeek(containing date: Date, calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
    }

    /// Start of the visible week, which may begin on Sunday.
    public static func startOfDisplayWeek(
        containing date: Date,
        weekStart: WeekStartDay,
        calendar: Calendar = .current
    ) -> Date {
        var cal = calendar
        cal.firstWeekday = weekStart.firstWeekday
        cal.minimumDaysInFirstWeek = 1
        return cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
    }

    /// Teaching week number for `date`; weeks before the term start are zero or negative.
    public static func teachingWeekNumber(
        termStart: Date,
        date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = startOfTeachingWeek(containing: termStart, calendar: calendar)
        let target = startOfTeachingWeek(containing: date, calendar: calendar)
        let days = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        return Int((Double(days) / 7.0).rounded(.down)) + 1
    }

    public static func addDays(_ days: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    public static func addWeeks(_ weeks: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: date) ?? date
    }
}

public enum DateOnly {

    /// Parse `yyyy-MM-dd` at noon so daylight-saving transitions cannot shift the day.
    public static func parse(_ raw: String, calendar: Calendar = .current) -> Date? {
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = calendar.date(from: components) else { return nil }

        // Calendar normalizes overflow (for example Feb 30), so verify the round trip.
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else {
            return nil
        }
        return date
    }

    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

/// A wall-clock time independent of any particular date.
public struct TimeOfDay: Hashable, Comparable, Sendable, Codable {

    public let minutes: Int

    public init(minutes: Int) {
        self.minutes = min(max(minutes, 0), 24 * 60 - 1)
    }

    public init(hour: Int, minute: Int) {
        self.init(minutes: hour * 60 + minute)
    }

    public init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    /// Parse `HH:mm`; returns nil for malformed or out-of-range input.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        self.minutes = hour * 60 + minute
    }

    public var hour: Int { minutes / 60 }
    public var minute: Int { minutes % 60 }

    public var text: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Resolve this wall-clock time on a given day.
    public func date(on day: Date, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutes < rhs.minutes
    }
}
