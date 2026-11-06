import CurSimpleCore
import SwiftUI

struct RootView: View {

    @Environment(AppStore.self) private var store

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("tab.schedule", systemImage: "calendar")
                }

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
        }
        .tint(store.preferences.accent.color)
    }
}
