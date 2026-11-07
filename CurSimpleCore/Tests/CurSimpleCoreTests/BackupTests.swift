import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Backup")
struct BackupTests {

    private func sampleState() -> AppState {
        let term = makeTerm(courses: [
            makeCourse(id: "a", title: "高数", day: 1, start: 1, end: 2),
        ])
        let profile = TimingProfile.defaultProfile()
        return AppState(
            terms: [term],
            activeTermID: term.id,
            timingProfiles: [profile],
            activeTimingProfileID: profile.id,
            memos: [MemoNote(id: "m1", title: "交作业")],
            holidayCalendar: HolidayCalendarSettings(entries: [
                HolidayCalendarEntry(date: "2026-09-07", kind: .holiday, name: "校庆"),
            ]),
            overrides: [
                TemporaryScheduleOverride(
                    type: .cancelCourse,
                    targetDate: "2026-09-08",
                    cancelStartNode: 1,
                    cancelEndNode: 2,
                    cancelCourseId: "a"
                ),
            ]
        )
    }

    @Test("Round trip keeps every collection")
    func roundTrip() throws {
        let state = sampleState()
        let payload = makeBackup(state: state, appVersion: "0.1.0", now: testDay("2026-11-07"))
        let data = try encodeBackup(payload)
        let decoded = try decodeBackup(data)

        #expect(decoded.state.terms.count == 1)
        #expect(decoded.state.terms[0].courses.count == 1)
        #expect(decoded.state.memos.count == 1)
        #expect(decoded.state.overrides.count == 1)
        #expect(decoded.state.holidayCalendar.entries.count == 1)

        let summary = backupSummary(decoded)
        #expect(summary.termCount == 1)
        #expect(summary.courseCount == 1)
        #expect(summary.memoCount == 1)
        #expect(summary.overrideCount == 1)
        #expect(summary.holidayEntryCount == 1)
    }

    @Test("Unknown versions and unreadable files are rejected")
    func rejection() throws {
        #expect(throws: BackupError.unreadable) {
            try decodeBackup(Data("not json".utf8))
        }

        var payload = makeBackup(state: sampleState(), appVersion: "0.1.0")
        payload.v = 99
        let data = try encodeBackup(payload)
        #expect(throws: BackupError.unsupportedVersion(99)) {
            try decodeBackup(data)
        }

        var empty = makeBackup(state: sampleState(), appVersion: "0.1.0")
        empty.state.terms = []
        let emptyData = try encodeBackup(empty)
        #expect(throws: BackupError.empty) {
            try decodeBackup(emptyData)
        }
    }

    @Test("Restore repairs a dangling active term and missing timing profile")
    func restoreRepairs() {
        var state = sampleState()
        state.activeTermID = "missing"
        state.timingProfiles = []
        state.activeTimingProfileID = ""

        let restored = restoredState(from: makeBackup(state: state, appVersion: "0.1.0"))
        #expect(restored.activeTermID == restored.terms.first?.id)
        #expect(restored.timingProfiles.count == 1)
        #expect(restored.activeTimingProfileID == TimingProfile.defaultID)
        #expect(restored.schemaVersion == AppState.currentSchemaVersion)
    }

    @Test("File names carry the export date")
    func fileName() {
        let name = backupFileName(now: testDay("2026-11-07"), calendar: makeTestCalendar())
        #expect(name == "cursimple-backup-2026-11-07.json")
    }
}

@Suite("Term management")
@MainActor
struct TermManagementTests {

    private func store() -> AppStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CurSimpleTermTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("state.json")
        return AppStore(storageURL: url, defaultTermName: "2026 秋")
    }

    @Test("Rename trims and ignores blank names")
    func rename() throws {
        let store = store()
        let id = try #require(store.activeTerm?.id)

        store.renameTerm(id: id, name: "  2027 春  ")
        #expect(store.activeTerm?.name == "2027 春")

        store.renameTerm(id: id, name: "   ")
        #expect(store.activeTerm?.name == "2027 春")
    }

    @Test("Copy duplicates courses with fresh ids and no week overrides")
    func copy() throws {
        let store = store()
        let termID = try #require(store.activeTerm?.id)
        var course = makeCourse(id: "orig", title: "高数", weeks: [1, 2])
        course.weekLocations = ["1": "A101"]
        store.addCourse(course)

        let copyID = try #require(store.copyTerm(id: termID, name: "新学期"))
        let copy = try #require(store.state.terms.first { $0.id == copyID })

        #expect(copy.name == "新学期")
        #expect(copy.courses.count == 1)
        #expect(copy.courses[0].id != "orig")
        #expect(copy.courses[0].title == "高数")
        #expect(copy.courses[0].weeks == [1, 2])
        #expect(copy.courses[0].weekLocations.isEmpty)
    }

    @Test("Deleting the active term activates another; the last term survives")
    func delete() throws {
        let store = store()
        let first = try #require(store.activeTerm?.id)
        store.addTerm(Term(name: "第二学期", startDate: "2027-02-22"))
        let second = try #require(store.state.terms.last?.id)

        store.deleteTerm(id: second)
        #expect(store.state.terms.count == 1)
        #expect(store.state.activeTermID == first)

        store.deleteTerm(id: first)
        #expect(store.state.terms.count == 1) // the last one is kept
    }
}
