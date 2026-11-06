import CurSimpleCore
import SwiftUI

// MARK: - Term

struct TermSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var termName = ""
    @State private var startDate: Date = .now
    @State private var weekCount = 20
    @State private var loaded = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "settings.term", colors: colors, onBack: {
                    save()
                    dismiss()
                })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsCard(colors: colors) {
                            fieldRow(colors: colors, label: "term.name") {
                                TextField("term.name", text: $termName)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(colors.onSurface)
                                    .onSubmit(save)
                            }

                            divider(colors)

                            fieldRow(colors: colors, label: "term.startDate") {
                                DatePicker(
                                    "",
                                    selection: $startDate,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                            }

                            divider(colors)

                            fieldRow(colors: colors, label: "term.weekCountLabel") {
                                HStack(spacing: 10) {
                                    Text(String(format: String(localized: "term.weekCount"), weekCount))
                                        .font(AppFont.bodySmall)
                                        .foregroundStyle(colors.onSurfaceVariant)
                                    Stepper("", value: $weekCount, in: 1...30)
                                        .labelsHidden()
                                }
                            }
                        }

                        SettingsCard(colors: colors) {
                            Text("term.footer")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(colors.onSurfaceVariant)
                        }

                        SettingsCard(colors: colors) {
                            HStack {
                                Text("settings.term.currentWeek")
                                    .font(AppFont.body)
                                    .foregroundStyle(colors.onSurface)
                                Spacer()
                                Text(currentWeekText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(colors.primary)
                            }
                            divider(colors)
                            HStack {
                                Text("term.courseCountLabel")
                                    .font(AppFont.body)
                                    .foregroundStyle(colors.onSurface)
                                Spacer()
                                Text(String(
                                    format: String(localized: "term.courseCount"),
                                    store.activeTerm?.courses.count ?? 0
                                ))
                                .font(AppFont.bodySmall)
                                .foregroundStyle(colors.onSurfaceVariant)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func fieldRow<Content: View>(
        colors: AppColors,
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer(minLength: 12)
            content()
        }
        .frame(minHeight: 44)
    }

    private func divider(_ colors: AppColors) -> some View {
        Divider().overlay(colors.outlineVariant).padding(.vertical, 2)
    }

    private var currentWeekText: String {
        guard let term = store.activeTerm,
              let start = term.startDateValue else {
            return String(localized: "term.notStarted")
        }
        let week = ScheduleCalendar.teachingWeekNumber(termStart: start, date: .now)
        guard week >= 1 else { return String(localized: "term.notStarted") }
        return String(format: String(localized: "week.number"), week)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let term = store.activeTerm else { return }
        termName = term.name
        weekCount = term.weekCount
        if let parsed = DateOnly.parse(term.startDate) {
            startDate = parsed
        }
    }

    private func save() {
        guard var term = store.activeTerm else { return }
        let trimmed = termName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { term.name = trimmed }
        term.startDate = DateOnly.string(from: startDate)
        term.weekCount = weekCount
        store.updateTerm(term)
    }
}

// MARK: - Timing

struct TimingSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var profile: TimingProfile = .defaultProfile()
    @State private var loaded = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "settings.timing", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsCard(colors: colors) {
                            ForEach($profile.slots) { $slot in
                                slotRow($slot, colors: colors)
                                if $slot.wrappedValue.startNode != profile.slots.last?.startNode {
                                    Divider().overlay(colors.outlineVariant)
                                }
                            }
                        }

                        SettingsCard(colors: colors) {
                            Text("timing.slots.footer")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(colors.onSurfaceVariant)
                        }

                        Button {
                            store.resetTimingProfile()
                            profile = store.timingProfile
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("timing.reset")
                                Spacer()
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(colors.error)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(colors.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
        .onChange(of: profile) { _, newValue in
            guard loaded else { return }
            store.updateTimingProfile(newValue)
        }
        .onDisappear {
            if loaded { store.updateTimingProfile(profile) }
        }
    }

    private func slotRow(_ slot: Binding<ClassSlotTime>, colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Text(String(
                format: String(localized: "schedule.periodCompact"),
                slot.wrappedValue.startNode
            ))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(colors.onSurface)
            .frame(width: 52, alignment: .leading)

            DatePicker(
                "",
                selection: Binding(
                    get: { slot.wrappedValue.start?.date(on: .now) ?? .now },
                    set: { slot.wrappedValue.startTime = TimeOfDay(date: $0).text }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_GB"))

            Text("–")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)

            DatePicker(
                "",
                selection: Binding(
                    get: { slot.wrappedValue.end?.date(on: .now) ?? .now },
                    set: { slot.wrappedValue.endTime = TimeOfDay(date: $0).text }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_GB"))

            Spacer(minLength: 0)
        }
        .frame(minHeight: 46)
    }

    private func load() {
        guard !loaded else { return }
        profile = store.timingProfile
        loaded = true
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "settings.appearance", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        accentCard(colors: colors)
                        paletteCard(colors: colors)
                        gridCard(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func accentCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("appearance.accent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onSurface)

            HStack(spacing: 12) {
                ForEach(AccentTheme.allCases) { theme in
                    Button {
                        var preferences = store.preferences
                        preferences.accent = theme
                        store.setPreferences(preferences)
                    } label: {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 34, height: 34)
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
            .padding(.top, 10)
        }
    }

    private func paletteCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("appearance.palette")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onSurface)

            VStack(spacing: 2) {
                ForEach(CoursePaletteStyle.allCases) { style in
                    let selected = store.preferences.paletteStyle == style
                    let entries = CoursePalette.entries(for: style, dark: colorScheme == .dark)

                    Button {
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
                                        .frame(width: 15, height: 15)
                                }
                            }

                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(selected ? colors.primary : colors.outline)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
    }

    private func gridCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("appearance.grid.header")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(colors.onSurface)

            HStack {
                Text("appearance.weekStart")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                HStack(spacing: 0) {
                    weekStartButton(.monday, colors: colors)
                    weekStartButton(.sunday, colors: colors)
                }
                .padding(2)
                .background(
                    Capsule().fill(colors.surfaceVariant)
                )
            }
            .padding(.top, 10)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 6)

            Toggle(isOn: Binding(
                get: { store.preferences.showWeekend },
                set: { value in
                    var preferences = store.preferences
                    preferences.showWeekend = value
                    store.setPreferences(preferences)
                }
            )) {
                Text("appearance.showWeekend")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
            }
            .tint(colors.primary)
        }
    }

    private func weekStartButton(_ value: WeekStartDay, colors: AppColors) -> some View {
        let selected = store.preferences.weekStart == value
        return Button {
            var preferences = store.preferences
            preferences.weekStart = value
            store.setPreferences(preferences)
        } label: {
            Text(value == .monday ? "appearance.weekStart.monday" : "appearance.weekStart.sunday")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(selected ? colors.primary : .clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About

struct AboutView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "settings.about", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(spacing: 10) {
                            Image("AppMark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            Text("app.name")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(colors.onSurface)

                            Text("about.tagline")
                                .font(AppFont.bodySmall)
                                .foregroundStyle(colors.onSurfaceVariant)
                                .multilineTextAlignment(.center)

                            Text("0.1.0")
                                .font(AppFont.label)
                                .foregroundStyle(colors.onSurfaceVariant)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(colors.surfaceVariant))
                        }
                        .padding(.vertical, 18)

                        SettingsCard(colors: colors) {
                            Link(destination: URL(string: "https://github.com/cursimple/cursimple-ios")!) {
                                aboutRow(icon: "chevron.left.forwardslash.chevron.right", title: "about.github", value: "GitHub", colors: colors)
                            }
                            Divider().overlay(colors.outlineVariant).padding(.vertical, 4)
                            aboutRow(icon: "doc.text", title: "about.license", value: "MIT", colors: colors)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func aboutRow(
        icon: String,
        title: LocalizedStringKey,
        value: String,
        colors: AppColors
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(colors.primary)
                .frame(width: 22)
            Text(title)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer()
            Text(value)
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .frame(minHeight: 40)
    }
}
