import CurSimpleCore
import Foundation
import WidgetKit

/// Publishes the resolved day to the widget's App Group container.
enum WidgetUpdater {

    @MainActor
    static func refresh(store: AppStore, now: Date = .now) {
        guard let term = store.activeTerm else { return }
        let snapshot = makeWidgetSnapshot(
            term: term,
            profile: store.timingProfile,
            holidayCalendar: store.state.holidayCalendar,
            overrides: store.state.overrides,
            paletteStyle: store.preferences.paletteStyle,
            now: now
        )
        if WidgetSharedStore.write(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
