import CurSimpleCore
import SwiftUI

@main
struct CurSimpleApp: App {

    @State private var store: AppStore

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleCourses") {
            let storage = AppStore.defaultStorageURL()
                .deletingLastPathComponent()
                .appendingPathComponent("sample-state.json")
            try? FileManager.default.removeItem(at: storage)
            let sampleStore = AppStore(storageURL: storage, defaultTermName: "2026-2027 第1学期")
            for course in SampleData.courses() {
                sampleStore.addCourse(course)
            }
            for memo in SampleData.memos() {
                sampleStore.upsertMemo(memo)
            }
            _store = State(initialValue: sampleStore)
            return
        }
        #endif

        _store = State(initialValue: AppStore(defaultTermName: Self.defaultTermName()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }

    private static func defaultTermName() -> String {
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let season = (2...7).contains(month)
            ? String(localized: "term.season.spring")
            : String(localized: "term.season.autumn")
        return "\(year) \(season)"
    }
}
