import Foundation

/// One course as the widget needs it; times carry both millis and display text
/// so the widget never has to re-resolve the term.
public struct WidgetCourseEntry: Codable, Hashable, Sendable, Identifiable {

    public let id: String
    public let title: String
    public let location: String
    public let teacher: String
    public let startMillis: Int64?
    public let endMillis: Int64?
    public let startText: String
    public let endText: String
    public let startNode: Int
    public let endNode: Int
    public let colorArgb: UInt32?
    public let isExam: Bool

    public init(
        id: String,
        title: String,
        location: String,
        teacher: String,
        startMillis: Int64?,
        endMillis: Int64?,
        startText: String,
        endText: String,
        startNode: Int,
        endNode: Int,
        colorArgb: UInt32?,
        isExam: Bool
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.teacher = teacher
        self.startMillis = startMillis
        self.endMillis = endMillis
        self.startText = startText
        self.endText = endText
        self.startNode = startNode
        self.endNode = endNode
        self.colorArgb = colorArgb
        self.isExam = isExam
    }
}

public struct WidgetDaySnapshot: Codable, Hashable, Sendable, Identifiable {

    public let dayMillis: Int64
    public let weekNumber: Int
    public let holidayName: String?
    public let courses: [WidgetCourseEntry]

    public init(dayMillis: Int64, weekNumber: Int, holidayName: String?, courses: [WidgetCourseEntry]) {
        self.dayMillis = dayMillis
        self.weekNumber = weekNumber
        self.holidayName = holidayName
        self.courses = courses
    }

    public var id: Int64 { dayMillis }
    public var isHoliday: Bool { holidayName != nil }
    public var holiday: String? {
        guard let holidayName, !holidayName.isEmpty else { return nil }
        return holidayName
    }
}

/// Compact, pre-resolved state for the home-screen widgets.
public struct WidgetSnapshot: Codable, Hashable, Sendable {

    public static let currentVersion = 2

    public let v: Int
    public let generatedAtMillis: Int64
    public let termName: String
    public let paletteStyle: String
    /// Start of the day the snapshot was built for.
    public let todayMillis: Int64
    /// Days around today; the today widget can page through them.
    public let days: [WidgetDaySnapshot]

    public init(
        v: Int = WidgetSnapshot.currentVersion,
        generatedAtMillis: Int64,
        termName: String,
        paletteStyle: String,
        todayMillis: Int64,
        days: [WidgetDaySnapshot]
    ) {
        self.v = v
        self.generatedAtMillis = generatedAtMillis
        self.termName = termName
        self.paletteStyle = paletteStyle
        self.todayMillis = todayMillis
        self.days = days
    }

    public var today: WidgetDaySnapshot? {
        days.first { $0.dayMillis == todayMillis } ?? days.first
    }
}

public func makeWidgetSnapshot(
    term: Term,
    profile: TimingProfile,
    holidayCalendar: HolidayCalendarSettings,
    overrides: [TemporaryScheduleOverride],
    paletteStyle: CoursePaletteStyle,
    now: Date,
    dayOffsets: ClosedRange<Int> = -1...6,
    calendar: Calendar = .current
) -> WidgetSnapshot {
    let todayStart = calendar.startOfDay(for: now)
    let todayMillis = Int64(todayStart.timeIntervalSince1970 * 1000)

    let days: [WidgetDaySnapshot] = dayOffsets.compactMap { offset in
        let date = ScheduleCalendar.addDays(offset, to: todayStart, calendar: calendar)
        let resolution = resolveScheduleDay(
            date: date,
            overrides: overrides,
            holidayCalendar: holidayCalendar,
            calendar: calendar
        )
        let items = scheduledCourseOccurrencesOn(
            date: date,
            courses: term.courses,
            timingProfile: profile,
            termStartDate: term.startDateValue,
            overrides: overrides,
            holidayCalendar: holidayCalendar,
            calendar: calendar
        )
        let week = term.startDateValue.map {
            ScheduleCalendar.teachingWeekNumber(termStart: $0, date: date, calendar: calendar)
        } ?? 0

        let entries = items.map { item -> WidgetCourseEntry in
            WidgetCourseEntry(
                id: item.course.id,
                title: item.title,
                location: item.location,
                teacher: item.teacher,
                startMillis: item.start.map { Int64($0.timeIntervalSince1970 * 1000) },
                endMillis: item.end.map { Int64($0.timeIntervalSince1970 * 1000) },
                startText: item.start.map { TimeOfDay(date: $0, calendar: calendar).text } ?? "",
                endText: item.end.map { TimeOfDay(date: $0, calendar: calendar).text } ?? "",
                startNode: item.course.time.startNode,
                endNode: item.course.time.endNode,
                colorArgb: item.course.colorArgb,
                isExam: item.course.category == .exam
            )
        }

        return WidgetDaySnapshot(
            dayMillis: Int64(calendar.startOfDay(for: date).timeIntervalSince1970 * 1000),
            weekNumber: week,
            holidayName: resolution.isHoliday ? (resolution.holidayName ?? "") : nil,
            courses: entries
        )
    }

    return WidgetSnapshot(
        generatedAtMillis: Int64(now.timeIntervalSince1970 * 1000),
        termName: term.name,
        paletteStyle: paletteStyle.rawValue,
        todayMillis: todayMillis,
        days: days
    )
}

/// Selected day when it still exists in the snapshot, otherwise today.
public func widgetDay(_ snapshot: WidgetSnapshot, selectedMillis: Int64? = nil) -> WidgetDaySnapshot? {
    if let selectedMillis,
       let day = snapshot.days.first(where: { $0.dayMillis == selectedMillis }) {
        return day
    }
    return snapshot.today
}

public func widgetCurrentCourse(_ day: WidgetDaySnapshot, at date: Date) -> WidgetCourseEntry? {
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return day.courses.first { entry in
        guard let start = entry.startMillis, let end = entry.endMillis else { return false }
        return start <= millis && millis < end
    }
}

public func widgetNextCourse(_ day: WidgetDaySnapshot, at date: Date) -> WidgetCourseEntry? {
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return day.courses.first { entry in
        guard let start = entry.startMillis else { return false }
        return start > millis
    }
}

/// First course starting after `date` across the snapshot's days, for the next widget.
public func widgetUpcomingCourse(
    _ snapshot: WidgetSnapshot,
    at date: Date
) -> (day: WidgetDaySnapshot, course: WidgetCourseEntry)? {
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    let ordered = snapshot.days.sorted { $0.dayMillis < $1.dayMillis }
    for day in ordered {
        for course in day.courses {
            if let start = course.startMillis, start > millis {
                return (day, course)
            }
        }
    }
    return nil
}

/// Progress through the current course, 0...1.
public func widgetProgress(_ entry: WidgetCourseEntry, at date: Date) -> Double {
    guard let start = entry.startMillis, let end = entry.endMillis, end > start else { return 0 }
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return min(max(Double(millis - start) / Double(end - start), 0), 1)
}
