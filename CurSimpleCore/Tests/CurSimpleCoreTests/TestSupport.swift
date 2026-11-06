import Foundation
@testable import CurSimpleCore

func makeTestCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    calendar.locale = Locale(identifier: "zh_CN")
    return calendar
}

func testDay(_ value: String) -> Date {
    DateOnly.parse(value, calendar: makeTestCalendar())!
}

func makeCourse(
    id: String = UUID().uuidString,
    title: String = "高等数学",
    day: Int = 1,
    start: Int = 1,
    end: Int = 2,
    weeks: [Int] = [],
    teacher: String = "",
    location: String = "",
    category: CourseCategory = .course,
    colorArgb: UInt32? = nil
) -> CourseItem {
    CourseItem(
        id: id,
        title: title,
        teacher: teacher,
        location: location,
        weeks: weeks,
        category: category,
        time: CourseTimeSlot(dayOfWeek: day, startNode: start, endNode: end),
        colorArgb: colorArgb
    )
}

func makeTerm(
    start: String = "2026-09-01",
    weekCount: Int = 20,
    courses: [CourseItem] = []
) -> Term {
    Term(name: "测试学期", startDate: start, weekCount: weekCount, courses: courses)
}
