import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Persistence", .serialized)
@MainActor
struct PersistenceTests {

    private func temporaryStorageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CurSimpleTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    @Test("State survives a store reload")
    func roundTrip() throws {
        let url = temporaryStorageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = AppStore(storageURL: url, defaultTermName: "2026 秋")
        let term = try #require(store.activeTerm)
        let course = makeCourse(id: "course-1", title: "线性代数", weeks: [1, 3, 5])

        store.addCourse(course)
        store.setPreferences(AppPreferences(accent: .purple, paletteStyle: .morandi, showWeekend: false))

        let reloaded = AppStore(storageURL: url, defaultTermName: "ignored")
        let reloadedTerm = try #require(reloaded.activeTerm)
        #expect(reloadedTerm.id == term.id)
        #expect(reloadedTerm.courses.count == 1)
        #expect(reloadedTerm.courses.first?.title == "线性代数")
        #expect(reloadedTerm.courses.first?.weeks == [1, 3, 5])
        #expect(reloaded.preferences.accent == .purple)
        #expect(reloaded.preferences.paletteStyle == .morandi)
        #expect(reloaded.preferences.showWeekend == false)
    }

    @Test("Courses update and delete")
    func mutations() throws {
        let url = temporaryStorageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = AppStore(storageURL: url, defaultTermName: "测试")
        var course = makeCourse(id: "a", title: "旧名字")
        store.addCourse(course)

        course.title = "新名字"
        store.updateCourse(course)
        #expect(store.activeTerm?.courses.first?.title == "新名字")

        store.deleteCourse(id: "a")
        #expect(store.activeTerm?.courses.isEmpty == true)
    }

    @Test("Missing optional keys decode with defaults")
    func backwardCompatibleDecoding() throws {
        let json = """
        {
          "id": "a",
          "title": "数学",
          "time": { "dayOfWeek": 1, "startNode": 1, "endNode": 2 }
        }
        """.data(using: .utf8)!

        let course = try JSONDecoder().decode(CourseItem.self, from: json)
        #expect(course.teacher.isEmpty)
        #expect(course.location.isEmpty)
        #expect(course.weeks.isEmpty)
        #expect(course.category == .course)
        #expect(course.hidden == false)
        #expect(course.colorArgb == nil)
    }

    @Test("A corrupt file is preserved instead of overwritten")
    func corruptFileBackup() throws {
        let url = temporaryStorageURL()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = AppStore(storageURL: url, defaultTermName: "恢复")
        #expect(store.activeTerm?.name == "恢复")

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.contains { $0.hasPrefix("state.corrupt-") })
    }

    @Test("Seeded state starts on the current Monday")
    func seed() throws {
        let calendar = makeTestCalendar()
        let now = testDay("2026-09-09")
        let state = AppStore.seeded(defaultTermName: "2026 秋", now: now, calendar: calendar)
        let term = try #require(state.activeTerm)
        #expect(term.startDate == "2026-09-07")
        #expect(term.weekCount == 20)
        #expect(state.timingProfiles.count == 1)
        #expect(state.timingProfiles[0].slots.count == 11)
    }
}
