import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Calendar and term weeks")
struct CalendarTests {

    let calendar = makeTestCalendar()

    @Test("Teaching weeks are anchored on Monday")
    func mondayAnchor() {
        let start = testDay("2026-09-01") // Tuesday
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-08-31"), calendar: calendar) == 1)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-09-06"), calendar: calendar) == 1)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-09-07"), calendar: calendar) == 2)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-09-13"), calendar: calendar) == 2)
    }

    @Test("Pre-term dates get zero or negative week numbers")
    func preTermWeeks() {
        let start = testDay("2026-09-01")
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-08-30"), calendar: calendar) == 0)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-08-23"), calendar: calendar) == -1)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-08-24"), calendar: calendar) == 0)
    }

    @Test("Week numbering crosses a year boundary")
    func yearBoundary() {
        let start = testDay("2025-12-29") // Monday
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-01-05"), calendar: calendar) == 2)
        #expect(ScheduleCalendar.teachingWeekNumber(termStart: start, date: testDay("2026-01-12"), calendar: calendar) == 3)
    }

    @Test("Display week can start on Sunday")
    func sundayDisplayWeek() {
        let date = testDay("2026-09-09") // Wednesday
        let monday = ScheduleCalendar.startOfDisplayWeek(containing: date, weekStart: .monday, calendar: calendar)
        let sunday = ScheduleCalendar.startOfDisplayWeek(containing: date, weekStart: .sunday, calendar: calendar)
        #expect(DateOnly.string(from: monday, calendar: calendar) == "2026-09-07")
        #expect(DateOnly.string(from: sunday, calendar: calendar) == "2026-09-06")
    }

    @Test("ISO weekday conversion")
    func isoWeekday() {
        #expect(ScheduleCalendar.isoDayOfWeek(testDay("2026-09-07"), calendar: calendar) == 1)
        #expect(ScheduleCalendar.isoDayOfWeek(testDay("2026-09-12"), calendar: calendar) == 6)
        #expect(ScheduleCalendar.isoDayOfWeek(testDay("2026-09-13"), calendar: calendar) == 7)
    }

    @Test("Date-only strings round trip")
    func dateOnlyRoundTrip() {
        let parsed = DateOnly.parse("2026-02-28", calendar: calendar)!
        #expect(DateOnly.string(from: parsed, calendar: calendar) == "2026-02-28")
        #expect(DateOnly.parse("2026-02-30", calendar: calendar) == nil)
        #expect(DateOnly.parse("not-a-date", calendar: calendar) == nil)
    }

    @Test("Time of day parses and orders")
    func timeOfDay() {
        #expect(TimeOfDay("08:05")?.minutes == 485)
        #expect(TimeOfDay("8:5")?.minutes == 485)
        #expect(TimeOfDay("25:00") == nil)
        #expect(TimeOfDay("08:60") == nil)
        #expect(TimeOfDay("08:00")! < TimeOfDay("09:00")!)
    }
}
