import Foundation

/// Weekday values (ISO numbering) in display order, not indices.
public func columnDayOfWeeks(
    weekStart: WeekStartDay,
    showWeekend: Bool,
    showSaturday: Bool
) -> [Int] {
    if !showWeekend {
        return showSaturday ? Array(1...6) : Array(1...5)
    }
    let start = weekStart.isoDayOfWeek
    return (0..<7).map { offset in
        ((start - 1 + offset) % 7) + 1
    }
}

/// Monday inside the visible week; identifies the teaching week when the display starts on Sunday.
public func displayWeekAnchorMonday(
    _ displayWeekStart: Date,
    calendar: Calendar = .current
) -> Date {
    let iso = ScheduleCalendar.isoDayOfWeek(displayWeekStart, calendar: calendar)
    let offset = (1 - iso + 7) % 7
    return ScheduleCalendar.addDays(offset, to: displayWeekStart, calendar: calendar)
}

public func displayWeekTermIndex(
    termStart: Date,
    displayWeekStart: Date,
    calendar: Calendar = .current
) -> Int {
    ScheduleCalendar.teachingWeekNumber(
        termStart: termStart,
        date: displayWeekAnchorMonday(displayWeekStart, calendar: calendar),
        calendar: calendar
    )
}

/// Date of a column in the visible week.
public func columnDate(
    displayWeekStart: Date,
    dayOfWeek: Int,
    weekStart: WeekStartDay,
    calendar: Calendar = .current
) -> Date {
    let offset = (dayOfWeek - weekStart.isoDayOfWeek + 7) % 7
    return ScheduleCalendar.addDays(offset, to: displayWeekStart, calendar: calendar)
}
