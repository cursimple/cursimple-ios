import Foundation

public struct ScheduledCourseOccurrence: Identifiable, Hashable, Sendable {

    public let course: CourseItem
    public let date: Date
    /// Teaching week at the source date; the week a moved course came from.
    public let sourceWeek: Int?
    public let start: Date?
    public let end: Date?

    public init(course: CourseItem, date: Date, sourceWeek: Int?, start: Date?, end: Date?) {
        self.course = course
        self.date = date
        self.sourceWeek = sourceWeek
        self.start = start
        self.end = end
    }

    public var id: String {
        "\(course.id)-\(course.time.startNode)-\(course.time.endNode)"
    }

    public var title: String { course.title(forWeek: sourceWeek) }
    public var teacher: String { course.teacher(forWeek: sourceWeek) }
    public var location: String { course.location(forWeek: sourceWeek) }
    public var hasTime: Bool { start != nil && end != nil }
}

/// The clock a course actually runs at: typed times first, then period slots, then typed fallbacks.
public func occurrenceClock(
    for course: CourseItem,
    profile: TimingProfile?
) -> (start: TimeOfDay, end: TimeOfDay)? {
    if let typed = course.typedClock {
        return typed
    }
    let start = profile?.slot(coveringNode: course.time.startNode)?.start
        ?? course.reminderStartTime.flatMap { TimeOfDay($0) }
    let end = profile?.slot(coveringNode: course.time.endNode)?.end
        ?? course.reminderEndTime.flatMap { TimeOfDay($0) }
    guard let start, let end, start < end else { return nil }
    return (start, end)
}

public func occurrences(
    on date: Date,
    term: Term,
    profile: TimingProfile?,
    calendar: Calendar = .current
) -> [ScheduledCourseOccurrence] {
    guard let week = term.weekNumber(on: date, calendar: calendar) else { return [] }
    return occurrences(
        on: date,
        courses: term.courses,
        week: week,
        profile: profile,
        calendar: calendar
    )
}

public func occurrences(
    on date: Date,
    courses: [CourseItem],
    week: Int,
    profile: TimingProfile?,
    calendar: Calendar = .current
) -> [ScheduledCourseOccurrence] {
    let isoDay = ScheduleCalendar.isoDayOfWeek(date, calendar: calendar)
    return courses
        .filter { !$0.hidden && $0.time.dayOfWeek == isoDay && $0.isActive(inWeek: week) }
        .map { course in
            let clock = occurrenceClock(for: course, profile: profile)
            return ScheduledCourseOccurrence(
                course: course,
                date: date,
                sourceWeek: week,
                start: clock?.start.date(on: date, calendar: calendar),
                end: clock?.end.date(on: date, calendar: calendar)
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.start, rhs.start) {
            case let (left?, right?):
                if left != right { return left < right }
                return lhs.course.time.startNode < rhs.course.time.startNode
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return lhs.course.time.startNode < rhs.course.time.startNode
            }
        }
}
