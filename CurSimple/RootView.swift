import CurSimpleCore
import SwiftUI

enum AppScreen: String, CaseIterable {
    case schedule
    case library
    case memo
    case alarm
    case settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .schedule: "tab.schedule"
        case .library: "tab.library"
        case .memo: "tab.memo"
        case .alarm: "tab.alarm"
        case .settings: "tab.settings"
        }
    }

    var icon: String {
        switch self {
        case .schedule: "calendar"
        case .library: "list.bullet.rectangle"
        case .memo: "checklist"
        case .alarm: "alarm"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {

    @Environment(AppStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @State private var screen: AppScreen = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-startSettings") { return .settings }
        if arguments.contains("-startLibrary") { return .library }
        if arguments.contains("-startAlarm") { return .alarm }
        if arguments.contains("-startMemo") { return .memo }
        if arguments.contains("-startLibrary") { return .library }
        if arguments.contains("-startAlarm") { return .alarm }
        if arguments.contains("-startMemo") { return .memo }
        return .schedule
    }()
    @State private var drawerOpen = ProcessInfo.processInfo.arguments.contains("-openDrawer")

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-widgetPreview") {
            WidgetPreviewScreen()
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .leading) {
            Group {
                switch screen {
                case .schedule:
                    ScheduleView(onOpenDrawer: openDrawer)
                case .library:
                    CourseLibraryView(onOpenDrawer: openDrawer)
                case .memo:
                    MemoView(onOpenDrawer: openDrawer)
                case .alarm:
                    AlarmListView(onOpenDrawer: openDrawer)
                case .settings:
                    SettingsView(onOpenDrawer: openDrawer)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if drawerOpen {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeDrawer)
                    .transition(.opacity)

                DrawerView(screen: $screen, isOpen: $drawerOpen)
                    .transition(.move(edge: .leading))
                    .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.24), value: drawerOpen)
        .task {
            WidgetUpdater.refresh(store: store)
            await reminders.refreshStatus()
            await reminders.reschedule(store: store)
            await reminders.rescheduleAlarms(store: store)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            WidgetUpdater.refresh(store: store)
            Task {
                await reminders.reschedule(store: store)
                await reminders.rescheduleAlarms(store: store)
            }
        }
        .onChange(of: store.state) { _, _ in
            WidgetUpdater.refresh(store: store)
            Task {
                await reminders.reschedule(store: store)
                await reminders.rescheduleAlarms(store: store)
            }
        }
    }

    private func openDrawer() {
        withAnimation(.easeOut(duration: 0.24)) {
            drawerOpen = true
        }
    }

    private func closeDrawer() {
        withAnimation(.easeOut(duration: 0.22)) {
            drawerOpen = false
        }
    }
}

struct DrawerView: View {

    @Binding var screen: AppScreen
    @Binding var isOpen: Bool

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let width = min(UIScreen.main.bounds.width * 0.78, 320)

        VStack(alignment: .leading, spacing: 6) {
            Image("AppMark")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                .padding(.top, 52)

            Text("app.name")
                .font(AppFont.appTitle)
                .foregroundStyle(colors.onSurface)
                .padding(.top, 10)

            Text(weekSubtitle)
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .padding(.bottom, 10)

            ForEach(AppScreen.allCases, id: \.self) { item in
                drawerItem(item, colors: colors)
            }

            Spacer(minLength: 12)

            Divider().overlay(colors.outlineVariant)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                Text("app.version")
                    .font(AppFont.label)
            }
            .foregroundStyle(colors.onSurfaceVariant)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 14)
        .frame(width: width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(colors.surface)
        .ignoresSafeArea()
    }

    private func drawerItem(_ item: AppScreen, colors: AppColors) -> some View {
        let selected = screen == item
        return Button {
            screen = item
            withAnimation(.easeOut(duration: 0.2)) {
                isOpen = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 22)
                Text(item.titleKey)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(selected ? colors.onPrimaryContainer : colors.onSurface)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? colors.primaryContainer : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var weekSubtitle: String {
        guard let term = store.activeTerm,
              let start = term.startDateValue else {
            return String(localized: "drawer.termStartUnset")
        }
        let week = ScheduleCalendar.teachingWeekNumber(termStart: start, date: .now)
        if week >= 1 {
            return String(format: String(localized: "drawer.currentWeek"), week)
        }
        return String(format: String(localized: "drawer.beforeTerm"), 1 - week)
    }
}
