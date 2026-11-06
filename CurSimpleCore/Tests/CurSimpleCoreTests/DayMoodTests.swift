import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Day mood lines")
struct DayMoodTests {

    let calendar = makeTestCalendar()

    private func context(_ date: Date, courses: Int, tomorrowHoliday: Bool? = nil) -> DayMoodContext {
        DayMoodContext(
            date: date,
            hour: calendar.component(.hour, from: date),
            isoWeekday: ScheduleCalendar.isoDayOfWeek(date, calendar: calendar),
            totalCourses: courses,
            tomorrowIsHoliday: tomorrowHoliday
        )
    }

    @Test("Late night wins over everything")
    func lateNight() {
        let fridayEvening = testDay("2026-11-06") // Friday
        let late = ScheduleCalendar.addDays(0, to: fridayEvening)
        var components = calendar.dateComponents([.year, .month, .day], from: late)
        components.hour = 23
        let moment = calendar.date(from: components)!

        #expect(dayMood(for: context(moment, courses: 3)) == .lateNight)
        #expect(dayMood(for: context(moment, courses: 0)) == .lateNight)
    }

    @Test("Empty days pick weekend or weekday free")
    func freeDay() {
        let saturday = testDay("2026-11-07")
        let monday = testDay("2026-11-09")

        #expect(dayMood(for: context(saturday, courses: 0)) == .weekendFree)
        #expect(dayMood(for: context(monday, courses: 0)) == .weekdayFree)
    }

    @Test("Done states prefer holiday, then Friday, then evening")
    func doneStates() {
        let friday = testDay("2026-11-06")
        let monday = testDay("2026-11-09")

        #expect(dayMood(for: context(friday, courses: 3, tomorrowHoliday: true)) == .doneTomorrowHoliday)
        #expect(dayMood(for: context(friday, courses: 3)) == .doneFriday)
        #expect(dayMood(for: context(monday, courses: 3)) == .done) // 12:00 default from DateOnly
    }

    @Test("Mood lines are stable for the same day")
    func stableLines() {
        let date = testDay("2026-11-06")
        let first = moodLine(for: .done, on: date)
        let second = moodLine(for: .done, on: date)
        #expect(first == second)
        #expect(first.isEmpty == false)
    }

    @Test("Every mood has lines in every locale table")
    func tablesComplete() {
        for mood in DayMood.allCases {
            #expect(!moodLines(for: mood, locale: "zh-Hans").isEmpty)
            #expect(!moodLines(for: mood, locale: "zh-Hant").isEmpty)
            #expect(!moodLines(for: mood, locale: "en").isEmpty)
        }
    }

    private func moodLine(for mood: DayMood, on date: Date) -> String {
        let lines = moodLines(for: mood, locale: "zh-Hans")
        return lines[dayMoodLineIndex(date: date, mood: mood, size: lines.count, calendar: calendar)]
    }
}
