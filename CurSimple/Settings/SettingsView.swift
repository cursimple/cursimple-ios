import CurSimpleCore
import SwiftUI

struct SettingsView: View {

    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        TermSettingsView()
                    } label: {
                        Label("settings.term", systemImage: "calendar.badge.clock")
                    }
                    NavigationLink {
                        TimingSettingsView()
                    } label: {
                        Label("settings.timing", systemImage: "clock.badge")
                    }
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        Label("settings.appearance", systemImage: "paintpalette")
                    }
                } header: {
                    Text("settings.section.schedule")
                }

                Section {
                    HStack {
                        Label("settings.about", systemImage: "info.circle")
                        Spacer()
                        Text("app.version")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("settings.about.footer")
                }
            }
            .navigationTitle("tab.settings")
        }
    }
}

// MARK: - Term settings

struct TermSettingsView: View {

    @Environment(AppStore.self) private var store

    @State private var startDate: Date = .now
    @State private var weekCount = 20
    @State private var termName = ""
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextField("term.name", text: $termName)
                    .onSubmit { save() }
                DatePicker("term.startDate", selection: $startDate, displayedComponents: .date)
                Stepper(value: $weekCount, in: 1...30) {
                    HStack {
                        Text("term.weekCountLabel")
                        Spacer()
                        Text(String(format: String(localized: "term.weekCount"), weekCount))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("term.footer")
            }
        }
        .navigationTitle("settings.term")
        .onAppear(perform: load)
        .onDisappear(perform: save)
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

// MARK: - Timing settings

struct TimingSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var profile: TimingProfile = .defaultProfile()
    @State private var loaded = false

    var body: some View {
        List {
            Section {
                ForEach($profile.slots) { $slot in
                    slotRow($slot)
                }
                .onMove { from, to in
                    profile.slots.move(fromOffsets: from, toOffset: to)
                }
            } header: {
                Text("timing.slots.header")
            } footer: {
                Text("timing.slots.footer")
            }

            Section {
                Button(role: .destructive) {
                    store.resetTimingProfile()
                    profile = store.timingProfile
                } label: {
                    Label("timing.reset", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("settings.timing")
        .onAppear(perform: load)
        .onDisappear(perform: save)
    }

    private func slotRow(_ slot: Binding<ClassSlotTime>) -> some View {
        HStack(spacing: 10) {
            Text(Format.periodRange(slot.wrappedValue.startNode, slot.wrappedValue.endNode))
                .font(.subheadline.weight(.medium))
                .frame(width: 64, alignment: .leading)

            DatePicker(
                "",
                selection: Binding(
                    get: { slot.wrappedValue.start?.date(on: .now) ?? .now },
                    set: { slot.wrappedValue.startTime = TimeOfDay(date: $0).text }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()

            Text("–")

            DatePicker(
                "",
                selection: Binding(
                    get: { slot.wrappedValue.end?.date(on: .now) ?? .now },
                    set: { slot.wrappedValue.endTime = TimeOfDay(date: $0).text }
                ),
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        profile = store.timingProfile
    }

    private func save() {
        store.updateTimingProfile(profile)
    }
}

// MARK: - Appearance settings

struct AppearanceSettingsView: View {

    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            @Bindable var store = store

            Section {
                Picker("appearance.accent", selection: Binding(
                    get: { store.preferences.accent },
                    set: { newValue in
                        var preferences = store.preferences
                        preferences.accent = newValue
                        store.setPreferences(preferences)
                    }
                )) {
                    ForEach(AccentTheme.allCases) { theme in
                        HStack {
                            Circle().fill(theme.color).frame(width: 14, height: 14)
                            Text(LocalizedStringKey(theme.localizationKey))
                        }
                        .tag(theme)
                    }
                }
            }

            Section {
                Picker("appearance.palette", selection: Binding(
                    get: { store.preferences.paletteStyle },
                    set: { newValue in
                        var preferences = store.preferences
                        preferences.paletteStyle = newValue
                        store.setPreferences(preferences)
                    }
                )) {
                    ForEach(CoursePaletteStyle.allCases) { style in
                        Text(LocalizedStringKey(style.localizationKey)).tag(style)
                    }
                }
            } header: {
                Text("appearance.palette.header")
            } footer: {
                Text("appearance.palette.footer")
            }

            Section {
                Picker("appearance.weekStart", selection: Binding(
                    get: { store.preferences.weekStart },
                    set: { newValue in
                        var preferences = store.preferences
                        preferences.weekStart = newValue
                        store.setPreferences(preferences)
                    }
                )) {
                    Text("appearance.weekStart.monday").tag(WeekStartDay.monday)
                    Text("appearance.weekStart.sunday").tag(WeekStartDay.sunday)
                }

                Toggle("appearance.showWeekend", isOn: Binding(
                    get: { store.preferences.showWeekend },
                    set: { newValue in
                        var preferences = store.preferences
                        preferences.showWeekend = newValue
                        store.setPreferences(preferences)
                    }
                ))
            } header: {
                Text("appearance.grid.header")
            }
        }
        .navigationTitle("settings.appearance")
    }
}
