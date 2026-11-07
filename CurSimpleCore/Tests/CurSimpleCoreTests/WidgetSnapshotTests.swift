import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Widget snapshot")
struct WidgetSnapshotTests {

    let calendar = makeTestCalendar()

    private func moment(_ day: String, hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        let parts = day.split(separator: "-").compactMap { Int($0) }
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = hour
        components.minute = minute
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }

    private var none: HolidayCalendarSettings {
        HolidayCalendarSettings(builtInEnabled: false)
    }

    @Test("Snapshot carries today's courses with display times")
    func dailyCourses() {
        let term = makeTerm(courses: [
            makeCourse(id: "a", title: "高等数学", day: 1, start: 1, end: 2, location: "A201"),
            makeCourse(id: "b", title: "大学英语", day: 1, start: 3, end: 4),
        ])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 9),
            calendar: calendar
        )

        #expect(snapshot.termName == term.name)
        #expect(snapshot.weekNumber == 2)
        #expect(snapshot.courses.count == 2)
        #expect(snapshot.courses[0].startText == "08:00")
        #expect(snapshot.courses[0].endText == "09:40")
        #expect(snapshot.courses[0].location == "A201")
        #expect(!snapshot.isHoliday)
    }

    @Test("Current and next resolve from millis")
    func currentAndNext() {
        let term = makeTerm(courses: [
            makeCourse(id: "a", title: "高数", day: 1, start: 1, end: 2),
            makeCourse(id: "b", title: "英语", day: 1, start: 3, end: 4),
        ])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 9),
            calendar: calendar
        )

        let current = widgetCurrentCourse(snapshot, at: moment("2026-09-07", hour: 9))
        #expect(current?.id == "a")
        let next = widgetNextCourse(snapshot, at: moment("2026-09-07", hour: 9))
        #expect(next?.id == "b")
        #expect(widgetCurrentCourse(snapshot, at: moment("2026-09-07", hour: 7)) == nil)
    }

    @Test("Progress clamps to 0...1")
    func progress() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 8),
            calendar: calendar
        )
        let entry = snapshot.courses[0]
        #expect(widgetProgress(entry, at: moment("2026-09-07", hour: 7)) == 0)
        #expect(abs(widgetProgress(entry, at: moment("2026-09-07", hour: 8, minute: 50)) - 0.5) < 0.02)
        #expect(widgetProgress(entry, at: moment("2026-09-07", hour: 10)) == 1)
    }

    @Test("Holidays clear the day and expose the name")
    func holiday() {
        var settings = none
        settings = settings.upsertingUser(HolidayCalendarEntry(date: "2026-09-07", kind: .holiday, name: "校庆"))
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: settings,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 9),
            calendar: calendar
        )
        #expect(snapshot.isHoliday)
        #expect(snapshot.holiday == "校庆")
        #expect(snapshot.courses.isEmpty)
    }

    @Test("Overrides and cancellations apply")
    func overrides() {
        let term = makeTerm(courses: [
            makeCourse(id: "keep", day: 1, start: 1, end: 2),
            makeCourse(id: "drop", day: 1, start: 3, end: 4),
        ])
        let override = TemporaryScheduleOverride(
            type: .cancelCourse,
            targetDate: "2026-09-07",
            cancelStartNode: 3,
            cancelEndNode: 4,
            cancelCourseId: "drop"
        )
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [override],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 7),
            calendar: calendar
        )
        #expect(snapshot.courses.map(\.id) == ["keep"])
    }

    @Test("Snapshot round trips through JSON")
    func codable() throws {
        let term = makeTerm(courses: [makeCourse(id: "a", title: "高数", day: 1, start: 1, end: 2)])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .morandi,
            now: moment("2026-09-07", hour: 8),
            calendar: calendar
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }
}
