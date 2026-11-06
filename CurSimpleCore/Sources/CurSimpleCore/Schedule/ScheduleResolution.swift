import Foundation

/// Resolved state of one day; holidays suppress classes and reminders.
public struct ScheduleDayResolution: Hashable, Sendable {

    public let date: Date
    /// The day whose timetable this date follows; equals `date` unless a make-up applies.
    public let sourceDate: Date
    public let isHoliday: Bool
    public let holidayName: String?
    /// Make-up workdays replace otherwise nonworking days.
    public let isMakeUpWorkday: Bool
    /// Partial-swap interval for make-ups.
    public let makeUpNodeRange: ClosedRange<Int>?

    public init(
        date: Date,
        sourceDate: Date,
        isHoliday: Bool,
        holidayName: String?,
        isMakeUpWorkday: Bool = false,
        makeUpNodeRange: ClosedRange<Int>? = nil
    ) {
        self.date = date
        self.sourceDate = sourceDate
        self.isHoliday = isHoliday
        self.holidayName = holidayName
        self.isMakeUpWorkday = isMakeUpWorkday
        self.makeUpNodeRange = makeUpNodeRange
    }
}

/**
 Apply manual day declarations, then explicit make-up overrides, then synced or bundled
 holidays. Course cancellations do not redefine the day's holiday status.
 */
public func resolveScheduleDay(
    date: Date,
    overrides: [TemporaryScheduleOverride],
    holidayCalendar: HolidayCalendarSettings,
    calendar: Calendar = .current
) -> ScheduleDayResolution {
    let userEntry = holidayCalendar.userEntry(on: date, calendar: calendar)
    let hasOverride = matchingTemporaryScheduleOverride(on: date, overrides: overrides, calendar: calendar) != nil
    let effectiveEntry: HolidayCalendarEntry?
    if let userEntry {
        effectiveEntry = userEntry
    } else if hasOverride {
        effectiveEntry = nil
    } else {
        effectiveEntry = holidayCalendar.syncedEntry(on: date, calendar: calendar)
            ?? holidayCalendar.builtInEntry(on: date, calendar: calendar)
    }

    let holiday = effectiveEntry?.kind == .holiday
    // Only mark workday overrides when the original day was nonworking.
    let isoWeekday = ScheduleCalendar.isoDayOfWeek(date, calendar: calendar)
    let makeUpWorkday = effectiveEntry?.kind == .workday && isoWeekday >= 6

    return ScheduleDayResolution(
        date: date,
        sourceDate: holiday
            ? date
            : resolveTemporaryScheduleSourceDate(for: date, overrides: overrides, calendar: calendar),
        isHoliday: holiday,
        holidayName: holiday ? effectiveEntry?.name.takeIf({ !$0.isEmpty }) : nil,
        isMakeUpWorkday: makeUpWorkday,
        makeUpNodeRange: holiday
            ? nil
            : matchingTemporaryScheduleOverride(on: date, overrides: overrides, calendar: calendar)?
                .makeUpNodeRange
    )
}

private extension String {
    func takeIf(_ predicate: (String) -> Bool) -> String? {
        predicate(self) ? self : nil
    }
}

/**
 Resolve source-week course coverage, moves and cancellations. `includeCancelled` supports
 restoration UI; a nil `termStartDate` disables week filtering.
 */
public func coursesScheduledOn(
    date: Date,
    courses: [CourseItem],
    overrides: [TemporaryScheduleOverride],
    holidayCalendar: HolidayCalendarSettings,
    termStartDate: Date?,
    includeCancelled: Bool = false,
    calendar: Calendar = .current
) -> [CourseItem] {
    let resolution = resolveScheduleDay(
        date: date,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        calendar: calendar
    )

    func isActiveOn(_ course: CourseItem, _ day: Date) -> Bool {
        guard let termStartDate else { return true }
        let week = ScheduleCalendar.teachingWeekNumber(
            termStart: termStartDate,
            date: day,
            calendar: calendar
        )
        return course.isActive(inWeek: week)
    }

    let movedIn = coursesMovedToWithOrigin(
        date: date,
        overrides: overrides,
        courseById: { id in courses.first { $0.id == id } },
        isOriginallyActive: isActiveOn,
        calendar: calendar
    ).map(\.course)

    let staying: [CourseItem]
    if resolution.isHoliday {
        staying = []
    } else {
        staying = courses
            .filter { !isCourseMovedAwayFrom(date: date, course: $0, overrides: overrides, calendar: calendar) }
            .filter { course in
                guard let source = temporaryScheduleCourseSourceDate(
                    date: date,
                    course: course,
                    sourceDate: resolution.sourceDate,
                    overrides: overrides,
                    calendar: calendar
                ) else {
                    return false
                }
                return isActiveOn(course, source)
            }
    }

    return (staying + movedIn)
        .filter { includeCancelled || !isCourseTemporarilyCancelled(on: date, course: $0, overrides: overrides, calendar: calendar) }
        .sorted {
            ($0.time.startNode, $0.time.endNode, $0.id) < ($1.time.startNode, $1.time.endNode, $1.id)
        }
}

/// Full occurrence resolution including timing, mirroring the shared planner.
public func scheduledCourseOccurrencesOn(
    date: Date,
    courses: [CourseItem],
    timingProfile: TimingProfile?,
    termStartDate: Date?,
    overrides: [TemporaryScheduleOverride],
    holidayCalendar: HolidayCalendarSettings,
    calendar: Calendar = .current
) -> [ScheduledCourseOccurrence] {
    let visible = courses.filter { !$0.hidden && !$0.reminderOnlyPlaceholder }
    let day = resolveScheduleDay(
        date: date,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        calendar: calendar
    )

    let movedSources = coursesMovedToWithOrigin(
        date: date,
        overrides: overrides,
        courseById: { id in visible.first { $0.id == id } },
        isOriginallyActive: { course, origin in
            guard let termStartDate else { return true }
            let week = ScheduleCalendar.teachingWeekNumber(termStart: termStartDate, date: origin, calendar: calendar)
            return course.isActive(inWeek: week)
        },
        calendar: calendar
    )
    .reduce(into: [String: Date]()) { result, pair in
        result[pair.course.id] = pair.origin
    }

    let scheduled = coursesScheduledOn(
        date: date,
        courses: visible,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        termStartDate: termStartDate,
        includeCancelled: false,
        calendar: calendar
    )

    var seen = Set<String>()
    return scheduled
        .filter { seen.insert("\($0.id)-\($0.time.startNode)-\($0.time.endNode)").inserted }
        .map { course -> ScheduledCourseOccurrence in
            let origin = movedSources[course.id]
                ?? temporaryScheduleCourseSourceDate(
                    date: date,
                    course: course,
                    sourceDate: day.sourceDate,
                    overrides: overrides,
                    calendar: calendar
                )
                ?? date
            let week = termStartDate.map {
                ScheduleCalendar.teachingWeekNumber(termStart: $0, date: origin, calendar: calendar)
            }
            let clock = occurrenceClock(for: course, profile: timingProfile)
            return ScheduledCourseOccurrence(
                course: course,
                date: date,
                sourceWeek: week,
                start: clock?.start.date(on: date, calendar: calendar),
                end: clock?.end.date(on: date, calendar: calendar)
            )
        }
        .sorted {
            switch ($0.start, $1.start) {
            case let (left?, right?):
                if left != right { return left < right }
                return $0.course.time.startNode < $1.course.time.startNode
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return $0.course.time.startNode < $1.course.time.startNode
            }
        }
}

private extension CourseItem {
    /// Reminder-only placeholders are not persisted in the iOS model yet.
    var reminderOnlyPlaceholder: Bool { false }
}
