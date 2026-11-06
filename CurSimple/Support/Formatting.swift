import CurSimpleCore
import SwiftUI

extension RGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

extension AccentTheme {
    var color: Color { baseColor.color }
}

enum Format {

    static func weekday(_ day: Int) -> String {
        switch day {
        case 1: String(localized: "weekday.monday")
        case 2: String(localized: "weekday.tuesday")
        case 3: String(localized: "weekday.wednesday")
        case 4: String(localized: "weekday.thursday")
        case 5: String(localized: "weekday.friday")
        case 6: String(localized: "weekday.saturday")
        case 7: String(localized: "weekday.sunday")
        default: String(localized: "common.unknown")
        }
    }

    static func weekdayNarrow(_ day: Int) -> String {
        switch day {
        case 1: String(localized: "weekday.narrow.monday")
        case 2: String(localized: "weekday.narrow.tuesday")
        case 3: String(localized: "weekday.narrow.wednesday")
        case 4: String(localized: "weekday.narrow.thursday")
        case 5: String(localized: "weekday.narrow.friday")
        case 6: String(localized: "weekday.narrow.saturday")
        case 7: String(localized: "weekday.narrow.sunday")
        default: String(localized: "common.unknown")
        }
    }

    static func period(_ node: Int) -> String {
        String(format: String(localized: "schedule.period"), node)
    }

    static func periodRange(_ start: Int, _ end: Int) -> String {
        let lower = min(start, end)
        let upper = max(start, end)
        if lower == upper { return period(lower) }
        return String(format: String(localized: "schedule.periodRange"), lower, upper)
    }

    static func timeRange(start: Date, end: Date) -> String {
        "\(TimeOfDay(date: start).text)–\(TimeOfDay(date: end).text)"
    }

    static func weekSummary(_ weeks: [Int]) -> String {
        if weeks.isEmpty {
            return String(localized: "course.weekSummary.all")
        }
        let separator = String(localized: "list.separator")
        let parts = weekRanges(weeks).map { range -> String in
            if range.lowerBound == range.upperBound {
                return "\(range.lowerBound)"
            }
            return String(
                format: String(localized: "course.weekRange"),
                range.lowerBound,
                range.upperBound
            )
        }
        return String(
            format: String(localized: "course.weekSummary"),
            parts.joined(separator: separator)
        )
    }

    static func remaining(until date: Date, from now: Date) -> String {
        let seconds = max(0, date.timeIntervalSince(now))
        let minutes = Int(ceil(seconds / 60))
        if minutes < 1 {
            return String(localized: "duration.lessThanMinute")
        }
        if minutes < 60 {
            return String(format: String(localized: "duration.minutes"), minutes)
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return String(format: String(localized: "duration.hours"), hours)
        }
        return String(format: String(localized: "duration.hoursMinutes"), hours, rest)
    }

    static func monthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().weekday(.wide))
    }
}
