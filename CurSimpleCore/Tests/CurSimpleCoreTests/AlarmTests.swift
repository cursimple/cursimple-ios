import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Alarms")
struct AlarmTests {

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

    @Test("Daily alarm fires tomorrow when today's time has passed")
    func nextFire() {
        let alarm = Alarm(hour: 7, minute: 30)
        // 2026-09-07 is a Monday.
        let fires = nextAlarmFires(
            alarm,
            after: moment("2026-09-07", hour: 8),
            count: 2,
            calendar: calendar
        )
        #expect(fires.count == 2)
        #expect(fires[0] == moment("2026-09-08", hour: 7, minute: 30))
        #expect(fires[1] == moment("2026-09-09", hour: 7, minute: 30))
    }

    @Test("Same-day alarm still fires when the time is ahead")
    func sameDay() {
        let alarm = Alarm(hour: 9, minute: 0)
        let fires = nextAlarmFires(
            alarm,
            after: moment("2026-09-07", hour: 8),
            count: 1,
            calendar: calendar
        )
        #expect(fires.first == moment("2026-09-07", hour: 9))
    }

    @Test("Weekday filters skip other days")
    func weekdays() {
        let alarm = Alarm(hour: 7, minute: 0, weekdays: [1, 3, 5]) // Mon, Wed, Fri
        let fires = nextAlarmFires(
            alarm,
            after: moment("2026-09-07", hour: 8), // Monday after 7am
            count: 3,
            calendar: calendar
        )
        #expect(fires == [
            moment("2026-09-09", hour: 7), // Wed
            moment("2026-09-11", hour: 7), // Fri
            moment("2026-09-14", hour: 7), // next Mon
        ])
    }

    @Test("Disabled alarms never fire")
    func disabled() {
        let alarm = Alarm(hour: 7, enabled: false)
        #expect(nextAlarmFires(alarm, after: moment("2026-09-07", hour: 0), calendar: calendar).isEmpty)
    }

    @Test("Values coerce on construction and decode")
    func coercion() throws {
        let alarm = Alarm(hour: 99, minute: -5, weekdays: [0, 9, 3, 3], snoozeMinutes: 999)
        #expect(alarm.hour == 23)
        #expect(alarm.minute == 0)
        #expect(alarm.weekdays == [3])
        #expect(alarm.snoozeMinutes == 60)

        let json = """
        {"id":"a","hour":25,"minute":70,"weekdays":[2,2,8],"snoozeMinutes":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Alarm.self, from: json)
        #expect(decoded.hour == 23)
        #expect(decoded.minute == 59)
        #expect(decoded.weekdays == [2])
        #expect(decoded.snoozeMinutes == 1)
    }

    @Test("Repeat summaries match common patterns")
    func summaries() {
        #expect(alarmRepeatSummary(Alarm()) == .everyDay)
        #expect(alarmRepeatSummary(Alarm(weekdays: [1, 2, 3, 4, 5])) == .weekdays)
        #expect(alarmRepeatSummary(Alarm(weekdays: [6, 7])) == .weekend)
        #expect(alarmRepeatSummary(Alarm(weekdays: [2, 4])) == .specific([2, 4]))
    }

    @Test("Sorting puts enabled alarms first by next fire")
    func sorting() {
        let late = Alarm(id: "late", hour: 20)
        let early = Alarm(id: "early", hour: 6)
        let off = Alarm(id: "off", hour: 1, enabled: false)
        let sorted = sortedAlarms([late, off, early], now: moment("2026-09-07", hour: 5), calendar: calendar)
        #expect(sorted.map(\.id) == ["early", "late", "off"])
    }
}
