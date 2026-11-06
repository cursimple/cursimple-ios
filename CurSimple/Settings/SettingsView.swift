import CurSimpleCore
import SwiftUI

enum SettingsRoute: Hashable {
    case term
    case timing
    case appearance
    case reminders
    case holidays
    case overrides
    case share
    case about
}

struct SettingsView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var path: [SettingsRoute] = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-openTermSettings") { return [.term] }
        if arguments.contains("-openTimingSettings") { return [.timing] }
        if arguments.contains("-openAppearanceSettings") { return [.appearance] }
        if arguments.contains("-openReminders") { return [.reminders] }
        if arguments.contains("-openHolidays") { return [.holidays] }
        if arguments.contains("-openOverrides") { return [.overrides] }
        if arguments.contains("-openShare") { return [.share] }
        if arguments.contains("-openAbout") { return [.about] }
        return []
    }()

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        NavigationStack(path: $path) {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    SettingsHeader(title: "tab.settings", colors: colors, onMenu: onOpenDrawer)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            heroCard(colors: colors)
                            courseTimeSection(colors: colors)
                            calendarSection(colors: colors)
                            reminderSection(colors: colors)
                            appearanceSection(colors: colors)
                            dataSection(colors: colors)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 28)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .term:
                    TermSettingsView()
                case .timing:
                    TimingSettingsView()
                case .appearance:
                    AppearanceSettingsView()
                case .reminders:
                    ReminderSettingsView()
                case .holidays:
                    HolidaySettingsView()
                case .overrides:
                    OverrideSettingsView()
                case .share:
                    ShareSettingsView()
                case .about:
                    AboutView()
                }
            }
        }
        .tint(colors.primary)
    }

    // MARK: - Hero

    private func heroCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("settings.common")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onPrimary)
                .padding(.horizontal, 2)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                NavigationLink(value: SettingsRoute.term) {
                    heroTile(
                        icon: "calendar",
                        title: "settings.term",
                        value: store.activeTerm?.name ?? "—",
                        colors: colors
                    )
                }
                NavigationLink(value: SettingsRoute.timing) {
                    heroTile(
                        icon: "clock",
                        title: "settings.timing",
                        value: String(
                            format: String(localized: "settings.timingValue"),
                            store.timingProfile.slots.count
                        ),
                        colors: colors
                    )
                }
                NavigationLink(value: SettingsRoute.appearance) {
                    heroTile(
                        icon: "paintpalette",
                        title: "settings.appearance",
                        value: Text(LocalizedStringKey(store.preferences.accent.localizationKey)),
                        colors: colors
                    )
                }
                NavigationLink(value: SettingsRoute.about) {
                    heroTile(
                        icon: "info.circle",
                        title: "settings.about",
                        value: "0.1.0",
                        colors: colors
                    )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colors.primary)
        )
    }

    private func heroTile(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(colors.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(colors.primaryContainer))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
                .lineLimit(1)

            Text(value)
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func heroTile(
        icon: String,
        title: LocalizedStringKey,
        value: Text,
        colors: AppColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(colors.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(colors.primaryContainer))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
                .lineLimit(1)

            value
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    // MARK: - Sections

    private func courseTimeSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "settings.courseAndTime", colors: colors)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                NavigationLink(value: SettingsRoute.term) {
                    sectionTile(
                        icon: "calendar.badge.clock",
                        title: "settings.termData",
                        value: termDataValue,
                        colors: colors
                    )
                }
                NavigationLink(value: SettingsRoute.timing) {
                    sectionTile(
                        icon: "clock",
                        title: "settings.timing",
                        value: String(
                            format: String(localized: "settings.timingValue"),
                            store.timingProfile.slots.count
                        ),
                        colors: colors
                    )
                }
                NavigationLink(value: SettingsRoute.appearance) {
                    sectionTile(
                        icon: "slider.horizontal.3",
                        title: "settings.display",
                        value: displayValue,
                        colors: colors
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func calendarSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "settings.calendarSection", colors: colors)

            HStack(spacing: 10) {
                NavigationLink(value: SettingsRoute.holidays) {
                    calendarTile(
                        icon: "calendar.badge.checkmark",
                        title: "settings.holidays",
                        value: holidayValue,
                        colors: colors
                    )
                }

                NavigationLink(value: SettingsRoute.overrides) {
                    calendarTile(
                        icon: "arrow.triangle.swap",
                        title: "settings.overrides",
                        value: String(
                            format: String(localized: "settings.overrides.value"),
                            store.state.overrides.count
                        ),
                        colors: colors
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func calendarTile(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(colors.primaryContainer))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onSurface)
                .lineLimit(1)

            Text(value)
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    private var holidayValue: String {
        let manual = store.state.holidayCalendar.entries.count
        let years = BuiltInHolidayCalendar.coveredYears
        guard let year = years.last else {
            return String(format: String(localized: "settings.holidays.valueNoBuiltIn"), manual)
        }
        return String(
            format: String(localized: "settings.holidays.value"),
            year,
            manual
        )
    }

    private func reminderSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "settings.remindersSection", colors: colors)

            NavigationLink(value: SettingsRoute.reminders) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(colors.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(colors.primaryContainer))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.reminders")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(colors.onSurface)
                        Text(reminderValue)
                            .font(AppFont.label)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colors.surface)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var reminderValue: String {
        let reminders = store.preferences.reminders.normalized
        guard reminders.enabled else { return String(localized: "settings.reminder.valueOff") }
        if reminders.advanceMinutes == 0 {
            return String(localized: "settings.reminder.valueAtStart")
        }
        return String(
            format: String(localized: "settings.reminder.value"),
            reminders.advanceMinutes
        )
    }

    private func dataSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "settings.dataSection", colors: colors)

            NavigationLink(value: SettingsRoute.share) {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(colors.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(colors.primaryContainer))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.share")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(colors.onSurface)
                        Text("settings.share.value")
                            .font(AppFont.label)
                            .foregroundStyle(colors.onSurfaceVariant)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colors.surface)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func appearanceSection(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "settings.appearanceSection", colors: colors)

            VStack(alignment: .leading, spacing: 14) {
                Text("appearance.accent")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.onSurfaceVariant)

                HStack(spacing: 14) {
                    ForEach(AccentTheme.allCases) { theme in
                        Button {
                            var preferences = store.preferences
                            preferences.accent = theme
                            store.setPreferences(preferences)
                        } label: {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if store.preferences.accent == theme {
                                        Circle()
                                            .stroke(colors.onSurface, lineWidth: 2)
                                            .padding(-4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(LocalizedStringKey(theme.localizationKey)))
                    }
                    Spacer()
                }

                Divider().overlay(colors.outlineVariant)

                Text("appearance.palette")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.onSurfaceVariant)

                VStack(spacing: 4) {
                    ForEach(CoursePaletteStyle.allCases) { style in
                        paletteRow(style, colors: colors)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(colors.surface)
            )
        }
    }

    private func sectionTile(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colors.primary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(colors.primaryContainer))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onSurface)
                .lineLimit(1)

            Text(value)
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surfaceVariant.opacity(0.55))
        )
    }

    private func paletteRow(_ style: CoursePaletteStyle, colors: AppColors) -> some View {
        let selected = store.preferences.paletteStyle == style
        let entries = CoursePalette.entries(for: style, dark: colorScheme == .dark)

        return Button {
            var preferences = store.preferences
            preferences.paletteStyle = style
            store.setPreferences(preferences)
        } label: {
            HStack(spacing: 10) {
                Text(LocalizedStringKey(style.localizationKey))
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(colors.onSurface)

                Spacer()

                HStack(spacing: 3) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.offset) { _, entry in
                        Circle()
                            .fill(entry.container.color)
                            .frame(width: 14, height: 14)
                    }
                }

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? colors.primary : colors.outline)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var termDataValue: String {
        guard let term = store.activeTerm,
              let date = DateOnly.parse(term.startDate) else {
            return String(localized: "term.notStarted")
        }
        let start = date.formatted(.dateTime.month().day())
        return String(
            format: String(localized: "settings.termData.value"),
            start,
            term.weekCount
        )
    }

    private var displayValue: String {
        let start = store.preferences.weekStart == .monday
            ? String(localized: "appearance.weekStart.monday")
            : String(localized: "appearance.weekStart.sunday")
        let weekend = store.preferences.showWeekend
            ? String(localized: "settings.weekendOn")
            : String(localized: "settings.weekendOff")
        return "\(start) · \(weekend)"
    }
}

// MARK: - Shared settings chrome

struct SettingsHeader: View {

    let title: LocalizedStringKey
    let colors: AppColors
    var onMenu: (() -> Void)?
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onBackground)

            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(colors.onBackground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("common.back")
                } else if let onMenu {
                    Button(action: onMenu) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(colors.onBackground)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("drawer.open")
                }

                Spacer()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 6)
    }
}

struct SettingsSectionLabel: View {

    let title: LocalizedStringKey
    let colors: AppColors

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colors.primary)
            .padding(.leading, 2)
            .padding(.top, 2)
    }
}

struct SettingsCard<Content: View>: View {

    let colors: AppColors
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colors.surface)
        )
    }
}
