import CurSimpleCore
import SwiftUI

@main
struct CurSimpleApp: App {

    @State private var store: AppStore

    init() {
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
