import Foundation

public struct Term: Codable, Identifiable, Hashable, Sendable {

    public var id: String
    public var name: String
    /// `yyyy-MM-dd`
    public var startDate: String
    public var weekCount: Int
    public var courses: [CourseItem]

    public init(
        id: String = UUID().uuidString,
        name: String,
        startDate: String,
        weekCount: Int = 20,
        courses: [CourseItem] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.weekCount = max(weekCount, 1)
        self.courses = courses
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, startDate, weekCount, courses
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate) ?? ""
        weekCount = max(try container.decodeIfPresent(Int.self, forKey: .weekCount) ?? 20, 1)
        courses = try container.decodeIfPresent([CourseItem].self, forKey: .courses) ?? []
    }

    public var startDateValue: Date? {
        DateOnly.parse(startDate)
    }

    /// Teaching week for a date, or nil when the start date cannot be read.
    public func weekNumber(on date: Date, calendar: Calendar = .current) -> Int? {
        guard let start = DateOnly.parse(startDate, calendar: calendar) else { return nil }
        return ScheduleCalendar.teachingWeekNumber(termStart: start, date: date, calendar: calendar)
    }

    public func courses(activeInWeek week: Int) -> [CourseItem] {
        courses.filter { !$0.hidden && $0.isActive(inWeek: week) }
    }
}
