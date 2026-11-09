import CryptoKit
import Foundation

/// What a school plugin submits through `schedule.write`.
public struct ScheduleDraft: Codable, Sendable {

    public var termId: String
    public var courses: [ScheduleDraftCourse]
    public var updatedAt: String?

    public init(termId: String, courses: [ScheduleDraftCourse] = [], updatedAt: String? = nil) {
        self.termId = termId
        self.courses = courses
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case termId, courses, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        termId = try container.decodeIfPresent(String.self, forKey: .termId) ?? ""
        courses = try container.decodeIfPresent([ScheduleDraftCourse].self, forKey: .courses) ?? []
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

public struct ScheduleDraftCourse: Codable, Sendable {
    public var id: String?
    public var title: String
    public var teacher: String?
    public var location: String?
    public var dayOfWeek: Int
    public var startNode: Int
    public var endNode: Int
    public var weeks: [Int]
    public var category: CourseCategory?
    public var details: [CourseDetailField]

    public init(
        id: String? = nil,
        title: String,
        teacher: String? = nil,
        location: String? = nil,
        dayOfWeek: Int,
        startNode: Int,
        endNode: Int,
        weeks: [Int] = [],
        category: CourseCategory? = nil,
        details: [CourseDetailField] = []
    ) {
        self.id = id
        self.title = title
        self.teacher = teacher
        self.location = location
        self.dayOfWeek = dayOfWeek
        self.startNode = startNode
        self.endNode = endNode
        self.weeks = weeks
        self.category = category
        self.details = details
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, teacher, location, dayOfWeek, startNode, endNode, weeks, category, details
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        dayOfWeek = try container.decodeIfPresent(Int.self, forKey: .dayOfWeek) ?? 0
        startNode = try container.decodeIfPresent(Int.self, forKey: .startNode) ?? 0
        endNode = try container.decodeIfPresent(Int.self, forKey: .endNode) ?? 0
        weeks = try container.decodeIfPresent([Int].self, forKey: .weeks) ?? []
        category = try? container.decodeIfPresent(CourseCategory.self, forKey: .category)
        details = try container.decodeIfPresent([CourseDetailField].self, forKey: .details) ?? []
    }
}

public enum ScheduleDraftError: Error, Equatable, Sendable {
    case tooManyCourses
    case blankTitle(Int)
    case invalidDayOfWeek(Int)
    case invalidStartNode(Int)
    case invalidEndNode(Int)
    case invalidWeeks(Int)
}

private let maxDraftDetailFields = 12
private let maxDetailLabelLength = 24
private let maxDetailValueLength = 200

/// Bound extra fields, drop empty values and keep the first of duplicate labels.
public func normalizedDraftDetails(_ details: [CourseDetailField]) -> [CourseDetailField] {
    var seen = Set<String>()
    return details.compactMap { field -> CourseDetailField? in
        let label = String(field.label.trimmingCharacters(in: .whitespaces).prefix(maxDetailLabelLength))
        let value = String(field.value.trimmingCharacters(in: .whitespaces).prefix(maxDetailValueLength))
        guard !label.isEmpty, !value.isEmpty, seen.insert(label).inserted else { return nil }
        return CourseDetailField(label: label, value: value)
    }
    .prefix(maxDraftDetailFields)
    .map { $0 }
}

/// Stable id for drafts that omit one, so re-imports update the same course.
public func stableDraftCourseID(index: Int, course: ScheduleDraftCourse) -> String {
    let raw = [
        String(index),
        course.title,
        course.teacher ?? "",
        course.location ?? "",
        String(course.dayOfWeek),
        String(course.startNode),
        String(course.endNode),
        course.weeks.map(String.init).joined(separator: ","),
    ].joined(separator: "|")
    let digest = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    return "plugin-" + String(digest.prefix(16))
}

/// Validate and normalize a draft into courses, rejecting anything out of range.
public func validatedDraftCourses(
    _ draft: ScheduleDraft,
    limits: PluginRuntimeLimits = .init()
) throws -> [CourseItem] {
    guard draft.courses.count <= limits.maxCourses else {
        throw ScheduleDraftError.tooManyCourses
    }

    return try draft.courses.enumerated().map { index, item in
        let title = item.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { throw ScheduleDraftError.blankTitle(index) }
        guard (1...7).contains(item.dayOfWeek) else {
            throw ScheduleDraftError.invalidDayOfWeek(item.dayOfWeek)
        }
        guard (1...32).contains(item.startNode) else {
            throw ScheduleDraftError.invalidStartNode(item.startNode)
        }
        guard (item.startNode...32).contains(item.endNode) else {
            throw ScheduleDraftError.invalidEndNode(item.endNode)
        }
        guard item.weeks.allSatisfy({ (1...60).contains($0) }) else {
            throw ScheduleDraftError.invalidWeeks(index)
        }

        let trimmedID = item.id?.trimmingCharacters(in: .whitespaces)
        let id = (trimmedID?.isEmpty == false ? trimmedID! : stableDraftCourseID(index: index, course: item))

        return CourseItem(
            id: id,
            title: title,
            teacher: (item.teacher ?? "").trimmingCharacters(in: .whitespaces),
            location: (item.location ?? "").trimmingCharacters(in: .whitespaces),
            weeks: item.weeks,
            category: item.category ?? .course,
            time: CourseTimeSlot(
                dayOfWeek: item.dayOfWeek,
                startNode: item.startNode,
                endNode: item.endNode
            ),
            details: normalizedDraftDetails(item.details)
        )
    }
}

/// Convert a draft into the courses of one term, sorted by day and period.
public func coursesFromDraft(
    _ draft: ScheduleDraft,
    limits: PluginRuntimeLimits = .init()
) throws -> [CourseItem] {
    try validatedDraftCourses(draft, limits: limits)
        .sorted {
            ($0.time.dayOfWeek, $0.time.startNode, $0.time.endNode, $0.title)
                < ($1.time.dayOfWeek, $1.time.startNode, $1.time.endNode, $1.title)
        }
}

/// Decode the `schedule.write` payload, which arrives as a JSON string.
public func decodeScheduleDraft(_ json: String) throws -> ScheduleDraft {
    guard let data = json.data(using: .utf8) else { throw ScheduleDraftError.blankTitle(0) }
    return try JSONDecoder().decode(ScheduleDraft.self, from: data)
}
