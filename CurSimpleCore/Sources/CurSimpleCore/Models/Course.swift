import Foundation

public struct CourseTimeSlot: Codable, Hashable, Sendable {
    /// ISO weekday: 1 = Monday ... 7 = Sunday.
    public var dayOfWeek: Int
    public var startNode: Int
    public var endNode: Int

    public init(dayOfWeek: Int, startNode: Int, endNode: Int) {
        self.dayOfWeek = dayOfWeek
        self.startNode = startNode
        self.endNode = endNode
    }

    public var nodeRange: ClosedRange<Int> {
        min(startNode, endNode)...max(startNode, endNode)
    }

    public var span: Int {
        max(startNode, endNode) - min(startNode, endNode) + 1
    }
}

public enum CourseCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case course
    case exam

    public var id: String { rawValue }
}

public struct CourseDetailField: Codable, Hashable, Sendable, Identifiable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var id: String { "\(label)\u{1F}\(value)" }
}

public struct CourseItem: Codable, Identifiable, Hashable, Sendable {

    public var id: String
    public var title: String
    public var teacher: String
    public var location: String
    /// Sparse per-week location overrides keyed by the week number as a string.
    public var weekLocations: [String: String]
    /// Empty means every teaching week.
    public var weeks: [Int]
    public var category: CourseCategory
    public var time: CourseTimeSlot
    public var slotLabelOverride: String?
    public var reminderStartTime: String?
    public var reminderEndTime: String?
    public var hidden: Bool
    public var details: [CourseDetailField]
    public var weekTeachers: [String: String]
    public var weekTitles: [String: String]
    /// Explicit fill color as 0xAARRGGBB; nil follows the palette.
    public var colorArgb: UInt32?
    public var colorEndArgb: UInt32?
    public var borderArgb: UInt32?

    public init(
        id: String = UUID().uuidString,
        title: String,
        teacher: String = "",
        location: String = "",
        weekLocations: [String: String] = [:],
        weeks: [Int] = [],
        category: CourseCategory = .course,
        time: CourseTimeSlot,
        slotLabelOverride: String? = nil,
        reminderStartTime: String? = nil,
        reminderEndTime: String? = nil,
        hidden: Bool = false,
        details: [CourseDetailField] = [],
        weekTeachers: [String: String] = [:],
        weekTitles: [String: String] = [:],
        colorArgb: UInt32? = nil,
        colorEndArgb: UInt32? = nil,
        borderArgb: UInt32? = nil
    ) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.location = location
        self.weekLocations = weekLocations
        self.weeks = Self.normalizedWeeks(weeks)
        self.category = category
        self.time = time
        self.slotLabelOverride = slotLabelOverride
        self.reminderStartTime = reminderStartTime
        self.reminderEndTime = reminderEndTime
        self.hidden = hidden
        self.details = details
        self.weekTeachers = weekTeachers
        self.weekTitles = weekTitles
        self.colorArgb = colorArgb
        self.colorEndArgb = colorEndArgb
        self.borderArgb = borderArgb
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, teacher, location, weekLocations, weeks, category, time
        case slotLabelOverride, reminderStartTime, reminderEndTime, hidden, details
        case weekTeachers, weekTitles, colorArgb, colorEndArgb, borderArgb
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        weekLocations = try container.decodeIfPresent([String: String].self, forKey: .weekLocations) ?? [:]
        weeks = Self.normalizedWeeks(try container.decodeIfPresent([Int].self, forKey: .weeks) ?? [])
        category = try container.decodeIfPresent(CourseCategory.self, forKey: .category) ?? .course
        time = try container.decode(CourseTimeSlot.self, forKey: .time)
        slotLabelOverride = try container.decodeIfPresent(String.self, forKey: .slotLabelOverride)
        reminderStartTime = try container.decodeIfPresent(String.self, forKey: .reminderStartTime)
        reminderEndTime = try container.decodeIfPresent(String.self, forKey: .reminderEndTime)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        details = try container.decodeIfPresent([CourseDetailField].self, forKey: .details) ?? []
        weekTeachers = try container.decodeIfPresent([String: String].self, forKey: .weekTeachers) ?? [:]
        weekTitles = try container.decodeIfPresent([String: String].self, forKey: .weekTitles) ?? [:]
        colorArgb = try container.decodeIfPresent(UInt32.self, forKey: .colorArgb)
        colorEndArgb = try container.decodeIfPresent(UInt32.self, forKey: .colorEndArgb)
        borderArgb = try container.decodeIfPresent(UInt32.self, forKey: .borderArgb)
    }

    private static func normalizedWeeks(_ weeks: [Int]) -> [Int] {
        Array(Set(weeks.filter { $0 >= 1 })).sorted()
    }
}

public extension CourseItem {

    func title(forWeek week: Int?) -> String {
        guard let week, let value = weekTitles[String(week)], !value.isEmpty else { return title }
        return value
    }

    func teacher(forWeek week: Int?) -> String {
        guard let week, let value = weekTeachers[String(week)], !value.isEmpty else { return teacher }
        return value
    }

    func location(forWeek week: Int?) -> String {
        guard let week, let value = weekLocations[String(week)], !value.isEmpty else { return location }
        return value
    }

    func isActive(inWeek week: Int) -> Bool {
        guard week >= 1 else { return false }
        return weeks.isEmpty || weeks.contains(week)
    }

    /// Both typed clock strings when present and ordered; nil means follow the period schedule.
    var typedClock: (start: TimeOfDay, end: TimeOfDay)? {
        guard let startRaw = reminderStartTime,
              let endRaw = reminderEndTime,
              let start = TimeOfDay(startRaw),
              let end = TimeOfDay(endRaw),
              start < end else {
            return nil
        }
        return (start, end)
    }
}

public extension Array where Element == CourseItem {
    func visibleCourses() -> [CourseItem] {
        filter { !$0.hidden }
    }
}
