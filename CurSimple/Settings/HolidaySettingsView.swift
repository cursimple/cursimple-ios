import CurSimpleCore
import SwiftUI

struct HolidaySettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var newDate: Date = .now
    @State private var newKind: HolidayEntryKind = .holiday
    @State private var newName = ""
    @State private var loaded = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let settings = store.state.holidayCalendar

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "holiday.pageTitle", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        builtInCard(settings, colors: colors)
                        addCard(colors: colors)
                        entriesCard(settings, colors: colors)
                        infoCard(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loaded = true }
    }

    // MARK: - Cards

    private func builtInCard(_ settings: HolidayCalendarSettings, colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Toggle(isOn: Binding(
                get: { settings.builtInEnabled },
                set: { value in
                    var calendar = store.state.holidayCalendar
                    calendar.builtInEnabled = value
                    store.setHolidayCalendar(calendar)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("holiday.useBuiltIn")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Text(builtInSummary)
                        .font(AppFont.label)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
            .tint(colors.primary)
        }
    }

    private func addCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "holiday.add", colors: colors)

            SettingsCard(colors: colors) {
                HStack {
                    Text("holiday.date")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    DatePicker("", selection: $newDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .frame(minHeight: 44)

                Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

                HStack(spacing: 8) {
                    Text("holiday.kind")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    kindChip(.holiday, colors: colors)
                    kindChip(.workday, colors: colors)
                }
                .frame(minHeight: 44)

                Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

                TextField("holiday.namePlaceholder", text: $newName)
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                    .frame(minHeight: 44)

                Button(action: addEntry) {
                    Text("common.add")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private func entriesCard(_ settings: HolidayCalendarSettings, colors: AppColors) -> some View {
        let entries = settings.entries.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "holiday.manual", colors: colors)

            if entries.isEmpty {
                SettingsCard(colors: colors) {
                    Text("holiday.empty")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            } else {
                SettingsCard(colors: colors) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry, colors: colors)
                        if index < entries.count - 1 {
                            Divider().overlay(colors.outlineVariant).padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: HolidayCalendarEntry, colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: entry.kind == .holiday ? "sun.max" : "briefcase")
                .font(.system(size: 13))
                .foregroundStyle(colors.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name.isEmpty ? String(localized: "holiday.name.generic") : entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colors.onSurface)
                Text(entry.date)
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
            }

            Spacer()

            Text(entry.kind == .holiday ? "holiday.kind.holiday" : "holiday.kind.workday")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(entry.kind == .holiday ? colors.primary : colors.onSurfaceVariant)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(colors.surfaceVariant))

            Button {
                store.removeHolidayEntry(date: entry.date)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.error)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("holiday.delete")
        }
        .frame(minHeight: 44)
    }

    private func infoCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("holiday.builtIn.footer")
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func kindChip(_ kind: HolidayEntryKind, colors: AppColors) -> some View {
        let selected = newKind == kind
        return Button {
            newKind = kind
        } label: {
            Text(kind == .holiday ? "holiday.kind.holiday" : "holiday.kind.workday")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(selected ? colors.primary : colors.surfaceVariant))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var builtInSummary: String {
        let years = BuiltInHolidayCalendar.coveredYears
        guard let year = years.last else { return "" }
        let count = BuiltInHolidayCalendar.entries(ofYear: year).count
        return String(format: String(localized: "holiday.useBuiltIn.summary"), year, count)
    }

    private func addEntry() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        store.upsertHolidayEntry(HolidayCalendarEntry(
            date: DateOnly.string(from: newDate),
            kind: newKind,
            name: name
        ))
        newName = ""
    }
}
