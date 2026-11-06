import Foundation

public enum TemporaryScheduleOverrideType: String, Codable, CaseIterable, Sendable, Identifiable {
    /// Swap a source day's courses onto a target day.
    case makeUp
    /// Cancel a course (or a node range) on specific dates.
    case cancelCourse
    /// Move one course without replacing other courses on either day.
    case moveCourse

    public var id: String { rawValue }
    public var localizationKey: String { "override.type.\(rawValue)" }
}

public struct TemporaryScheduleOverride: Codable, Identifiable, Hashable, Sendable {

    public var id: String
    public var type: TemporaryScheduleOverrideType
    /// Make-up destination day: `yyyy-MM-dd`.
    public var targetDate: String
    /// Make-up source day (whose courses land on the target).
    public var sourceDate: String
    /// Legacy ranged make-up records.
    public var startDate: String
    public var endDate: String
    public var sourceDayOfWeek: Int?
    /// Cancel bounds.
    public var cancelStartNode: Int?
    public var cancelEndNode: Int?
    public var cancelCourseId: String?
    /// Partial make-up bounds; nil means a whole-day swap.
    public var makeUpStartNode: Int?
    public var makeUpEndNode: Int?
    /// Move-course source and destination period bounds.
    public var moveCourseId: String?
    public var moveToStartNode: Int?
    public var moveToEndNode: Int?

    public init(
        id: String = UUID().uuidString,
        type: TemporaryScheduleOverrideType = .makeUp,
        targetDate: String = "",
        sourceDate: String = "",
        startDate: String = "",
        endDate: String = "",
        sourceDayOfWeek: Int? = nil,
        cancelStartNode: Int? = nil,
        cancelEndNode: Int? = nil,
        cancelCourseId: String? = nil,
        makeUpStartNode: Int? = nil,
        makeUpEndNode: Int? = nil,
        moveCourseId: String? = nil,
        moveToStartNode: Int? = nil,
        moveToEndNode: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.targetDate = targetDate
        self.sourceDate = sourceDate
        self.startDate = startDate
        self.endDate = endDate
        self.sourceDayOfWeek = sourceDayOfWeek
        self.cancelStartNode = cancelStartNode
        self.cancelEndNode = cancelEndNode
        self.cancelCourseId = cancelCourseId
        self.makeUpStartNode = makeUpStartNode
        self.makeUpEndNode = makeUpEndNode
        self.moveCourseId = moveCourseId
        self.moveToStartNode = moveToStartNode
        self.moveToEndNode = moveToEndNode
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, targetDate, sourceDate, startDate, endDate, sourceDayOfWeek
        case cancelStartNode, cancelEndNode, cancelCourseId
        case makeUpStartNode, makeUpEndNode
        case moveCourseId, moveToStartNode, moveToEndNode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = (try? container.decodeIfPresent(TemporaryScheduleOverrideType.self, forKey: .type)) ?? .makeUp
        targetDate = try container.decodeIfPresent(String.self, forKey: .targetDate) ?? ""
        sourceDate = try container.decodeIfPresent(String.self, forKey: .sourceDate) ?? ""
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate) ?? ""
        sourceDayOfWeek = try container.decodeIfPresent(Int.self, forKey: .sourceDayOfWeek)
        cancelStartNode = try container.decodeIfPresent(Int.self, forKey: .cancelStartNode)
        cancelEndNode = try container.decodeIfPresent(Int.self, forKey: .cancelEndNode)
        cancelCourseId = try container.decodeIfPresent(String.self, forKey: .cancelCourseId)
        makeUpStartNode = try container.decodeIfPresent(Int.self, forKey: .makeUpStartNode)
        makeUpEndNode = try container.decodeIfPresent(Int.self, forKey: .makeUpEndNode)
        moveCourseId = try container.decodeIfPresent(String.self, forKey: .moveCourseId)
        moveToStartNode = try container.decodeIfPresent(Int.self, forKey: .moveToStartNode)
        moveToEndNode = try container.decodeIfPresent(Int.self, forKey: .moveToEndNode)
    }
}

public extension TemporaryScheduleOverride {

    private static func parse(_ raw: String, calendar: Calendar) -> Date? {
        DateOnly.parse(raw, calendar: calendar)
    }

    /// The source day whose courses land on `date`, or nil when the rule does not cover it.
    func sourceDateFor(_ date: Date, calendar: Calendar = .current) -> Date? {
        guard type == .makeUp else { return nil }

        let explicitTarget = Self.parse(targetDate, calendar: calendar)
        let explicitSource = Self.parse(sourceDate, calendar: calendar)
        if explicitTarget != nil || explicitSource != nil {
            guard let target = explicitTarget, calendar.isDate(target, inSameDayAs: date) else {
                return nil
            }
            return explicitSource
        }

        // Legacy weekday records use a Monday anchor, independent of display week start.
        guard let weekday = sourceDayOfWeek, (1...7).contains(weekday),
              let start = Self.parse(startDate, calendar: calendar),
              let end = Self.parse(endDate, calendar: calendar) else {
            return nil
        }
        let lower = min(start, end)
        let upper = max(start, end)
        guard date >= calendar.startOfDay(for: lower), date <= calendar.startOfDay(for: upper) else {
            return nil
        }
        let monday = ScheduleCalendar.startOfTeachingWeek(containing: date, calendar: calendar)
        return ScheduleCalendar.addDays(weekday - 1, to: monday, calendar: calendar)
    }

    func containsDate(_ date: Date, calendar: Calendar = .current) -> Bool {
        sourceDateFor(date, calendar: calendar) != nil
    }

    /// Explicit target, or every day in a legacy range.
    func targetDates(calendar: Calendar = .current) -> [Date] {
        if let target = Self.parse(targetDate, calendar: calendar) {
            return [target]
        }
        guard let start = Self.parse(startDate, calendar: calendar),
              let end = Self.parse(endDate, calendar: calendar) else {
            return []
        }
        let lower = min(start, end)
        let upper = max(start, end)
        var dates: [Date] = []
        var cursor = lower
        while cursor <= upper {
            dates.append(cursor)
            cursor = ScheduleCalendar.addDays(1, to: cursor, calendar: calendar)
        }
        return dates
    }

    func cancelsCourse(on date: Date, course: CourseItem, calendar: Calendar = .current) -> Bool {
        guard type == .cancelCourse else { return false }
        guard targetDates(calendar: calendar).contains(where: { calendar.isDate($0, inSameDayAs: date) }) else {
            return false
        }
        if let required = cancelCourseId, !required.isEmpty, required != course.id {
            return false
        }
        guard let start = cancelStartNode else { return false }
        let end = cancelEndNode ?? start
        let lower = min(start, end)
        let upper = max(start, end)
        return course.time.startNode <= upper && course.time.endNode >= lower
    }

    /// Nil for whole-day swaps, otherwise the affected node interval.
    var makeUpNodeRange: ClosedRange<Int>? {
        guard type == .makeUp else { return nil }
        guard let start = makeUpStartNode ?? makeUpEndNode,
              let end = makeUpEndNode ?? makeUpStartNode else {
            return nil
        }
        return min(start, end)...max(start, end)
    }

    var moveToNodeRange: ClosedRange<Int>? {
        guard type == .moveCourse else { return nil }
        guard let start = moveToStartNode else { return nil }
        let end = moveToEndNode ?? start
        return min(start, end)...max(start, end)
    }
}

public func matchingTemporaryScheduleOverride(
    on date: Date,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> TemporaryScheduleOverride? {
    overrides.reversed().first { $0.containsDate(date, calendar: calendar) }
}

public func resolveTemporaryScheduleSourceDate(
    for date: Date,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> Date {
    matchingTemporaryScheduleOverride(on: date, overrides: overrides, calendar: calendar)?
        .sourceDateFor(date, calendar: calendar) ?? date
}

public func isCourseTemporarilyCancelled(
    on date: Date,
    course: CourseItem,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> Bool {
    overrides.contains { $0.cancelsCourse(on: date, course: course, calendar: calendar) }
}

private func overrideDate(_ raw: String) -> Date? {
    DateOnly.parse(raw)
}

private func overrideDateString(_ date: Date, calendar: Calendar) -> String {
    DateOnly.string(from: date, calendar: calendar)
}

/// Suppress courses moved away from their original date.
public func isCourseMovedAwayFrom(
    date: Date,
    course: CourseItem,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> Bool {
    let key = overrideDateString(date, calendar: calendar)
    return overrides.contains { rule in
        rule.type == .moveCourse && rule.moveCourseId == course.id && rule.sourceDate == key
    }
}

/// Whether `course` was individually moved into `date`.
public func isCourseMovedTo(
    date: Date,
    course: CourseItem,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> Bool {
    let key = overrideDateString(date, calendar: calendar)
    return overrides.contains { rule in
        rule.type == .moveCourse && rule.moveCourseId == course.id && rule.targetDate == key
    }
}

/// Materialize courses moved into `date`, keeping the origin for source-week labels.
public func coursesMovedToWithOrigin(
    date: Date,
    overrides: [TemporaryScheduleOverride],
    courseById: (String) -> CourseItem?,
    isOriginallyActive: (CourseItem, Date) -> Bool = { _, _ in true },
    calendar: Calendar = .current
) -> [(course: CourseItem, origin: Date)] {
    let dateKey = overrideDateString(date, calendar: calendar)
    return overrides.compactMap { rule -> (course: CourseItem, origin: Date)? in
        guard rule.type == .moveCourse else { return nil }
        guard rule.targetDate == dateKey else { return nil }
        guard let origin = overrideDate(rule.sourceDate) else { return nil }
        guard let courseId = rule.moveCourseId else { return nil }
        guard var course = courseById(courseId) else { return nil }
        guard isOriginallyActive(course, origin) else { return nil }
        guard let nodes = rule.moveToNodeRange else { return nil }

        course.time = CourseTimeSlot(
            dayOfWeek: ScheduleCalendar.isoDayOfWeek(date, calendar: calendar),
            startNode: nodes.lowerBound,
            endNode: nodes.upperBound
        )
        return (course, origin)
    }
}

/// Resolve a course's source day under whole-day or partial swaps; nil means no occurrence.
public func temporaryScheduleCourseSourceDate(
    date: Date,
    course: CourseItem,
    sourceDate: Date,
    overrides: [TemporaryScheduleOverride],
    calendar: Calendar = .current
) -> Date? {
    if calendar.isDate(sourceDate, inSameDayAs: date) {
        return course.time.dayOfWeek == ScheduleCalendar.isoDayOfWeek(date, calendar: calendar) ? date : nil
    }
    let range = matchingTemporaryScheduleOverride(on: date, overrides: overrides, calendar: calendar)?
        .makeUpNodeRange
    guard let range else {
        return course.time.dayOfWeek == ScheduleCalendar.isoDayOfWeek(sourceDate, calendar: calendar)
            ? sourceDate : nil
    }
    let inRange = course.time.startNode <= range.upperBound && course.time.endNode >= range.lowerBound
    if inRange {
        return course.time.dayOfWeek == ScheduleCalendar.isoDayOfWeek(sourceDate, calendar: calendar)
            ? sourceDate : nil
    }
    return course.time.dayOfWeek == ScheduleCalendar.isoDayOfWeek(date, calendar: calendar) ? date : nil
}


public struct CourseMovePlan: Hashable, Sendable {
    public var removeIds: [String]
    public var upsert: TemporaryScheduleOverride?

    public init(removeIds: [String] = [], upsert: TemporaryScheduleOverride? = nil) {
        self.removeIds = removeIds
        self.upsert = upsert
    }
}

/// Rewrite an existing move rather than chaining copies. Returning to the natural
/// date and periods removes the override; the natural nodes identify that position.
public func planCourseMove(
    overrides: [TemporaryScheduleOverride],
    courseId: String,
    from date: Date,
    to target: Date,
    toStartNode: Int,
    toEndNode: Int,
    naturalStartNode: Int,
    naturalEndNode: Int,
    newId: () -> String,
    calendar: Calendar = .current
) -> CourseMovePlan {
    let from = DateOnly.string(from: date, calendar: calendar)
    let to = DateOnly.string(from: target, calendar: calendar)
    let backToNaturalNodes = toStartNode == naturalStartNode && toEndNode == naturalEndNode

    let movedIn = overrides.lastOrNull { rule in
        rule.type == .moveCourse
            && rule.moveCourseId == courseId
            && rule.targetDate == from
    }
    if let movedIn {
        if to == movedIn.sourceDate && backToNaturalNodes {
            return CourseMovePlan(removeIds: [movedIn.id])
        }
        var updated = movedIn
        updated.targetDate = to
        updated.moveToStartNode = toStartNode
        updated.moveToEndNode = toEndNode
        return CourseMovePlan(upsert: updated)
    }

    return CourseMovePlan(
        upsert: TemporaryScheduleOverride(
            id: newId(),
            type: .moveCourse,
            targetDate: to,
            sourceDate: from,
            moveCourseId: courseId,
            moveToStartNode: toStartNode,
            moveToEndNode: toEndNode
        )
    )
}

private extension Array {
    func lastOrNull(_ predicate: (Element) -> Bool) -> Element? {
        reversed().first(where: predicate)
    }
}
