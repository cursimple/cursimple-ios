import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Share codec")
struct ShareCodecTests {

    let calendar = makeTestCalendar()

    private func sampleTerm() -> Term {
        makeTerm(courses: [
            makeCourse(id: "a", title: "高等数学", day: 1, start: 1, end: 2, weeks: [1, 3, 5],
                       teacher: "张老师", location: "教学楼-A201"),
            makeCourse(id: "b", title: "大学英语", day: 2, start: 3, end: 4, location: "博文楼-B305"),
            makeCourse(id: "c", title: "考试", day: 5, start: 9, end: 10, category: .exam),
        ])
    }

    @Test("Round trip keeps courses and timing slots")
    func roundTrip() throws {
        let term = sampleTerm()
        let profile = TimingProfile.defaultProfile()
        let payload = makeSharePayload(term: term, profile: profile, now: testDay("2026-09-07"))
        let code = try ShareCodec.encode(payload)

        #expect(code.hasPrefix("CSV1:"))
        #expect(!code.contains("+"))
        #expect(!code.contains("/"))

        let decoded = try ShareCodec.decode(code)
        #expect(decoded.v == 1)
        #expect(decoded.termName == term.name)
        #expect(decoded.termStartDate == "2026-09-01")
        #expect(decoded.timingSlots.count == profile.slots.count)
        #expect(decoded.schedule?.dailySchedules.flatMap(\.courses).count == 3)

        let imported = importedTimetable(
            from: decoded,
            fallbackName: "导入",
            now: testDay("2026-09-07"),
            calendar: calendar
        )
        #expect(imported?.term.courses.count == 3)
        #expect(imported?.term.name == term.name)
        #expect(imported?.term.startDate == "2026-09-01")
    }

    @Test("Share code tolerates whitespace inserted by messaging apps")
    func whitespace() throws {
        let code = try ShareCodec.encode(makeSharePayload(term: sampleTerm(), profile: .defaultProfile()))
        let broken = code.chunked(into: 40).joined(separator: "\n ")
        #expect(try ShareCodec.decode(broken).v == 1)
    }

    @Test("Hidden courses are not shared")
    func hiddenCourses() throws {
        var hidden = makeCourse(id: "h", title: "隐藏课")
        hidden.hidden = true
        let term = makeTerm(courses: [makeCourse(id: "a", title: "可见课"), hidden])
        let payload = makeSharePayload(term: term, profile: .defaultProfile())
        let courses = payload.schedule?.dailySchedules.flatMap(\.courses) ?? []
        #expect(courses.map(\.id) == ["a"])
    }

    @Test("Wrong prefixes and malformed bodies are rejected")
    func rejection() {
        #expect(throws: ShareCodecError.notShareData) {
            try ShareCodec.decode("not a share code")
        }
        #expect(throws: ShareCodecError.notShareData) {
            try ShareCodec.decode("CSV1:not-base64!!!")
        }
        #expect(throws: ShareCodecError.malformed) {
            try ShareCodec.decode("CSV1:" + ShareCodec.base64URL(Data("plain text".utf8)))
        }
    }

    @Test("Version 2 payloads are rejected")
    func versionRejected() throws {
        let payload = ScheduleSharePayload(v: 2, termName: "新版本")
        let code = try ShareCodec.encode(payload)
        #expect(throws: ShareCodecError.notShareData) {
            try ShareCodec.decode(code)
        }
    }

    @Test("Gzip output matches the platform container")
    func gzipContainer() throws {
        let original = Data("hello 课简 hello 课简".utf8)
        let compressed = try #require(Gzip.compress(original))
        #expect(compressed[0] == 0x1F)
        #expect(compressed[1] == 0x8B)
        #expect(compressed[2] == 0x08)
        // Trailer ISIZE is the uncompressed length, little endian.
        let size = Int(compressed[compressed.count - 4])
            | (Int(compressed[compressed.count - 3]) << 8)
            | (Int(compressed[compressed.count - 2]) << 16)
            | (Int(compressed[compressed.count - 1]) << 24)
        #expect(size == original.count)
        #expect(Gzip.decompress(compressed, limit: 1024) == original)
    }

    @Test("Import is additive and infers week coverage")
    func importRules() {
        let course = makeCourse(id: "w", title: "长周课", weeks: [1, 2, 25])
        let payload = ScheduleSharePayload(
            termName: "别人的学期",
            termStartDate: "2026-09-01",
            schedule: SharedTermSchedule(
                termId: "other",
                dailySchedules: [SharedDailySchedule(dayOfWeek: 1, courses: [course])]
            ),
            timingSlots: TimingProfile.defaultProfile().slots
        )
        let imported = importedTimetable(
            from: payload,
            fallbackName: "导入",
            now: testDay("2026-09-07"),
            calendar: calendar
        )
        #expect(imported?.term.weekCount == 25)
        #expect(imported?.term.id != payload.schedule?.termId)
        #expect(imported?.timingSlots.count == 11)
    }

    @Test("A Python-generated gzip payload decodes")
    func platformFixture() throws {
        // Produced with Python's gzip + urlsafe_b64encode (same container Java writes).
        let fixture = "CSV1:H4sIAAAAAAAA_6tWKlOyMtRRKkktyvVLzE1VslJ6trX7xfqpT9cuezZnvhJEJrgksajEJbEEJG1kYGSma2Cpa2AIlCxOzkhNKc0BileDFXqmAFWkZVaUlBalAqVLC1KAmlIcS4CiQG5KYmZOZTBUS7GSVXQ1UKjSPy08NTUb7Irk_NKiYqhMJtgokCUlmSUgG5Rerp7xbOoGsEAu2EZUzcUgR_rlp6SCeal5KRC2UW1tLBDqKOUm5pUm5jjDrYgFG5SZlx6ck18CFqgFAJyCM8sOAQAA"
        let payload = try ShareCodec.decode(fixture)
        #expect(payload.v == 1)
        #expect(payload.termName == "测试学期")
        let courses = payload.schedule?.dailySchedules.flatMap(\.courses) ?? []
        #expect(courses.count == 1)
        #expect(courses.first?.title == "高数")
    }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}
