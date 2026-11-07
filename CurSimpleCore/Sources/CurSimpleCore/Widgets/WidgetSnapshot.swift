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
        self.colorArgb = colorArgb
        self.isExam = isExam
    }
}

/// Compact, pre-resolved state for the home-screen widget.
public struct WidgetSnapshot: Codable, Hashable, Sendable {

    public static let currentVersion = 1

    public let v: Int
    public let generatedAtMillis: Int64
    public let termName: String
    public let weekNumber: Int
    public let dayMillis: Int64
    public let holidayName: String?
    public let paletteStyle: String
    public let courses: [WidgetCourseEntry]

    public init(
        v: Int = WidgetSnapshot.currentVersion,
        generatedAtMillis: Int64,
        termName: String,
        weekNumber: Int,
        dayMillis: Int64,
        holidayName: String?,
        paletteStyle: String,
        courses: [WidgetCourseEntry]
    ) {
        self.v = v
        self.generatedAtMillis = generatedAtMillis
        self.termName = termName
        self.weekNumber = weekNumber
        self.dayMillis = dayMillis
        self.holidayName = holidayName
        self.paletteStyle = paletteStyle
        self.courses = courses
    }

    public var isHoliday: Bool { holidayName != nil }

    public var holiday: String? {
        guard let holidayName, !holidayName.isEmpty else { return nil }
        return holidayName
    }
}

public func makeWidgetSnapshot(
    term: Term,
    profile: TimingProfile,
    holidayCalendar: HolidayCalendarSettings,
    overrides: [TemporaryScheduleOverride],
    paletteStyle: CoursePaletteStyle,
    now: Date,
    calendar: Calendar = .current
) -> WidgetSnapshot {
    let day = resolveScheduleDay(
        date: now,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        calendar: calendar
    )
    let items = scheduledCourseOccurrencesOn(
        date: now,
        courses: term.courses,
        timingProfile: profile,
        termStartDate: term.startDateValue,
        overrides: overrides,
        holidayCalendar: holidayCalendar,
        calendar: calendar
    )
    let week = term.startDateValue.map {
        ScheduleCalendar.teachingWeekNumber(termStart: $0, date: now, calendar: calendar)
    } ?? 0

    let entries = items.map { item -> WidgetCourseEntry in
        let startMillis = item.start.map { Int64($0.timeIntervalSince1970 * 1000) }
        let endMillis = item.end.map { Int64($0.timeIntervalSince1970 * 1000) }
        return WidgetCourseEntry(
            id: item.course.id,
            title: item.title,
            location: item.location,
            teacher: item.teacher,
            startMillis: startMillis,
            endMillis: endMillis,
            startText: item.start.map { TimeOfDay(date: $0, calendar: calendar).text } ?? "",
            endText: item.end.map { TimeOfDay(date: $0, calendar: calendar).text } ?? "",
            colorArgb: item.course.colorArgb,
            isExam: item.course.category == .exam
        )
    }

    return WidgetSnapshot(
        generatedAtMillis: Int64(now.timeIntervalSince1970 * 1000),
        termName: term.name,
        weekNumber: week,
        dayMillis: Int64(calendar.startOfDay(for: now).timeIntervalSince1970 * 1000),
        holidayName: day.isHoliday
            ? (day.holidayName?.isEmpty == false ? day.holidayName : "")
            : nil,
        paletteStyle: paletteStyle.rawValue,
        courses: entries
    )
}

/// Current course at `date`, or nil outside class time.
public func widgetCurrentCourse(_ snapshot: WidgetSnapshot, at date: Date) -> WidgetCourseEntry? {
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return snapshot.courses.first { entry in
        guard let start = entry.startMillis, let end = entry.endMillis else { return false }
        return start <= millis && millis < end
    }
}

/// Next course starting after `date`, including one already in progress? No: strictly later.
public func widgetNextCourse(_ snapshot: WidgetSnapshot, at date: Date) -> WidgetCourseEntry? {
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return snapshot.courses.first { entry in
        guard let start = entry.startMillis else { return false }
        return start > millis
    }
}

/// Progress through the current course, 0...1.
public func widgetProgress(_ entry: WidgetCourseEntry, at date: Date) -> Double {
    guard let start = entry.startMillis, let end = entry.endMillis, end > start else { return 0 }
    let millis = Int64(date.timeIntervalSince1970 * 1000)
    return min(max(Double(millis - start) / Double(end - start), 0), 1)
}
