import Foundation

/// Versioned compact payload containing only what is needed to view a timetable.
public struct ScheduleSharePayload: Codable, Sendable {

    public static let currentVersion = 1
    public static let magicPrefix = "CSV1:"

    public var v: Int
    public var termName: String?
    public var termStartDate: String?
    public var schedule: SharedTermSchedule?
    public var manualCourses: [CourseItem]
    public var timingSlots: [ClassSlotTime]

    public init(
        v: Int = ScheduleSharePayload.currentVersion,
        termName: String? = nil,
        termStartDate: String? = nil,
        schedule: SharedTermSchedule? = nil,
        manualCourses: [CourseItem] = [],
        timingSlots: [ClassSlotTime] = []
    ) {
        self.v = v
        self.termName = termName
        self.termStartDate = termStartDate
        self.schedule = schedule
        self.manualCourses = manualCourses
        self.timingSlots = timingSlots
    }

    private enum CodingKeys: String, CodingKey {
        case v, termName, termStartDate, schedule, manualCourses, timingSlots
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        v = try container.decodeIfPresent(Int.self, forKey: .v) ?? ScheduleSharePayload.currentVersion
        termName = try container.decodeIfPresent(String.self, forKey: .termName)
        termStartDate = try container.decodeIfPresent(String.self, forKey: .termStartDate)
        schedule = try container.decodeIfPresent(SharedTermSchedule.self, forKey: .schedule)
        manualCourses = try container.decodeIfPresent([CourseItem].self, forKey: .manualCourses) ?? []
        timingSlots = try container.decodeIfPresent([ClassSlotTime].self, forKey: .timingSlots) ?? []
    }
}

public struct SharedTermSchedule: Codable, Sendable {

    public var termId: String
    public var updatedAt: String
    public var dailySchedules: [SharedDailySchedule]
    public var sourcePluginId: String?
    public var sourceName: String?
    public var legacyDisplayPluginId: String?
    public var externalImport: Bool?

    public init(
        termId: String,
        updatedAt: String = "",
        dailySchedules: [SharedDailySchedule] = [],
        sourcePluginId: String? = nil,
        sourceName: String? = nil,
        legacyDisplayPluginId: String? = nil,
        externalImport: Bool? = nil
    ) {
        self.termId = termId
        self.updatedAt = updatedAt
        self.dailySchedules = dailySchedules
        self.sourcePluginId = sourcePluginId
        self.sourceName = sourceName
        self.legacyDisplayPluginId = legacyDisplayPluginId
        self.externalImport = externalImport
    }
}

public struct SharedDailySchedule: Codable, Sendable {
    public var dayOfWeek: Int
    public var courses: [CourseItem]

    public init(dayOfWeek: Int, courses: [CourseItem] = []) {
        self.dayOfWeek = dayOfWeek
        self.courses = courses
    }
}

// MARK: - Build and import

/// Build a share payload from one term and its timing profile.
public func makeSharePayload(
    term: Term,
    profile: TimingProfile,
    now: Date = .now
) -> ScheduleSharePayload {
    let visible = term.courses.filter { !$0.hidden }
    let daily = (1...7).map { day in
        SharedDailySchedule(
            dayOfWeek: day,
            courses: visible.filter { $0.time.dayOfWeek == day }
        )
    }
    let formatter = ISO8601DateFormatter()
    return ScheduleSharePayload(
        termName: term.name,
        termStartDate: term.startDate,
        schedule: SharedTermSchedule(
            termId: term.id,
            updatedAt: formatter.string(from: now),
            dailySchedules: daily,
            externalImport: true
        ),
        manualCourses: [],
        timingSlots: profile.slots
    )
}

public struct ImportedTimetable: Sendable {

    public let term: Term
    public let timingSlots: [ClassSlotTime]
    public let warnings: [String]

    public init(term: Term, timingSlots: [ClassSlotTime], warnings: [String]) {
        self.term = term
        self.timingSlots = timingSlots
        self.warnings = warnings
    }
}

/**
 Convert a shared payload into a fresh term.

 The import is additive: it never edits existing terms. Courses from the payload
 keep their week coverage and per-week overrides; hidden entries are dropped.
 */
public func importedTimetable(
    from payload: ScheduleSharePayload,
    fallbackName: String,
    now: Date = .now,
    calendar: Calendar = .current
) -> ImportedTimetable? {
    guard payload.v == ScheduleSharePayload.currentVersion else { return nil }

    var warnings: [String] = []
    var courses: [CourseItem] = []
    var seen = Set<String>()

    func append(_ course: CourseItem, day: Int?) {
        var course = course
        if let day, !(1...7).contains(course.time.dayOfWeek) {
            course.time.dayOfWeek = day
        }
        guard !course.hidden, (1...7).contains(course.time.dayOfWeek) else { return }
        guard seen.insert(course.id).inserted else {
            warnings.append("duplicate course id: \(course.id)")
            return
        }
        courses.append(course)
    }

    for day in payload.schedule?.dailySchedules ?? [] {
        for course in day.courses {
            append(course, day: day.dayOfWeek)
        }
    }
    for course in payload.manualCourses {
        append(course, day: nil)
    }

    let name = payload.termName?.trimmingCharacters(in: .whitespaces)
    let termName = (name?.isEmpty == false ? name! : fallbackName)
    let startDate = payload.termStartDate.flatMap { DateOnly.parse($0, calendar: calendar) }
        ?? ScheduleCalendar.startOfDisplayWeek(containing: now, weekStart: .monday, calendar: calendar)
    let explicitMaxWeek = courses.map { $0.weeks.max() ?? 0 }.max() ?? 0
    let weekCount = max(defaultTermWeekCount, explicitMaxWeek)

    let term = Term(
        name: termName,
        startDate: DateOnly.string(from: startDate, calendar: calendar),
        weekCount: weekCount,
        courses: courses.sorted {
            ($0.time.dayOfWeek, $0.time.startNode, $0.title)
                < ($1.time.dayOfWeek, $1.time.startNode, $1.title)
        }
    )

    return ImportedTimetable(
        term: term,
        timingSlots: payload.timingSlots,
        warnings: warnings
    )
}
