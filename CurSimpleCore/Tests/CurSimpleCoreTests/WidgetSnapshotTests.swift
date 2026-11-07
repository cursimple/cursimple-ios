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

    @Test("Snapshot carries the surrounding days")
    func days() {
        let term = makeTerm(courses: [
            makeCourse(id: "mon", title: "高等数学", day: 1, start: 1, end: 2, location: "A201"),
            makeCourse(id: "tue", title: "大学英语", day: 2, start: 3, end: 4),
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

        #expect(snapshot.days.count == 8) // -1...6
        #expect(snapshot.today?.dayMillis == Int64(moment("2026-09-07", hour: 0).timeIntervalSince1970 * 1000))
        #expect(snapshot.today?.courses.count == 1)
        #expect(snapshot.days.first { $0.weekNumber == 2 && $0.courses.contains { $0.id == "tue" } } != nil)
    }

    @Test("Entries expose nodes for the period label")
    func periodLabelInputs() throws {
        let term = makeTerm(courses: [makeCourse(id: "a", title: "高数", day: 1, start: 1, end: 2)])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 9),
            calendar: calendar
        )
        let entry = try #require(snapshot.today?.courses.first)
        #expect(entry.startNode == 1)
        #expect(entry.endNode == 2)
        #expect(entry.startText == "08:00")
        #expect(entry.endText == "09:40")
    }

    @Test("Current / next / progress resolve within a day")
    func currentAndNext() throws {
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
        let day = try #require(snapshot.today)

        #expect(widgetCurrentCourse(day, at: moment("2026-09-07", hour: 9))?.id == "a")
        #expect(widgetNextCourse(day, at: moment("2026-09-07", hour: 9))?.id == "b")
        #expect(widgetCurrentCourse(day, at: moment("2026-09-07", hour: 7)) == nil)

        let entry = try #require(day.courses.first)
        #expect(widgetProgress(entry, at: moment("2026-09-07", hour: 8, minute: 50)) > 0.4)
        #expect(widgetProgress(entry, at: moment("2026-09-07", hour: 12)) == 1)
    }

    @Test("Upcoming course crosses into the next day")
    func upcomingAcrossDays() throws {
        let term = makeTerm(courses: [
            makeCourse(id: "mon", day: 1, start: 1, end: 2),
            makeCourse(id: "tue", day: 2, start: 1, end: 2),
        ])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 20),
            calendar: calendar
        )
        let upcoming = widgetUpcomingCourse(snapshot, at: moment("2026-09-07", hour: 20))
        #expect(upcoming?.course.id == "tue")
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
        #expect(snapshot.today?.isHoliday == true)
        #expect(snapshot.today?.holiday == "校庆")
        #expect(snapshot.today?.courses.isEmpty == true)
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
        #expect(snapshot.today?.courses.map(\.id) == ["keep"])
    }

    @Test("Selected day falls back to today when out of range")
    func selectedDay() {
        let term = makeTerm(courses: [makeCourse(id: "a", day: 1, start: 1, end: 2)])
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: .defaultProfile(),
            holidayCalendar: none,
            overrides: [],
            paletteStyle: .standard,
            now: moment("2026-09-07", hour: 9),
            calendar: calendar
        )
        let tomorrow = snapshot.days.first { $0.dayMillis > snapshot.todayMillis }
        #expect(widgetDay(snapshot, selectedMillis: tomorrow?.dayMillis)?.dayMillis == tomorrow?.dayMillis)
        #expect(widgetDay(snapshot, selectedMillis: 123)?.dayMillis == snapshot.todayMillis)
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
