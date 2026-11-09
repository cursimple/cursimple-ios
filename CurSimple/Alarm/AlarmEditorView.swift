import CurSimpleCore
import SwiftUI

/// Create or edit a manual alarm: time wheel, repeat days, label and snooze.
struct AlarmEditorView: View {

    let alarm: Alarm
    let onSave: (Alarm) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStore.self) private var store

    @State private var time: Date = .now
    @State private var weekdays: Set<Int> = []
    @State private var label = ""
    @State private var snoozeMinutes = 5
    @State private var loaded = false
    @State private var showDelete = false

    private var isNew: Bool { alarm.createdAtMillis == 0 }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        timeCard(colors: colors)
                        repeatCard(colors: colors)
                        optionsCard(colors: colors)

                        if !isNew {
                            Button {
                                showDelete = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("alarm.delete")
                                    Spacer()
                                }
                                .appFont(14, weight: .medium)
                                .foregroundStyle(colors.error)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(colors.error.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("alarm.delete", isPresented: $showDelete, titleVisibility: .visible) {
            Button("alarm.delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("alarm.delete.message")
        }
    }

    private func header(colors: AppColors) -> some View {
        ZStack {
            Text(isNew ? "alarm.new" : "alarm.edit")
                .appFont(16, weight: .semibold)
                .foregroundStyle(colors.onBackground)

            HStack {
                Button("common.cancel") { dismiss() }
                    .appFont(14)
                    .foregroundStyle(colors.primary)

                Spacer()

                Button(action: save) {
                    Text("common.save")
                        .appFont(13, weight: .semibold)
                        .foregroundStyle(colors.onPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }

    private func timeCard(colors: AppColors) -> some View {
        DatePicker(
            "",
            selection: $time,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func repeatCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "alarm.repeat", colors: colors)

            SettingsCard(colors: colors) {
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { day in
                        let selected = weekdays.contains(day)
                        Button {
                            if selected {
                                weekdays.remove(day)
                            } else {
                                weekdays.insert(day)
                            }
                        } label: {
                            Text(Format.weekdayNarrow(day))
                                .appFont(13, weight: .semibold)
                                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? colors.primary : colors.surfaceVariant)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    quickRepeat("alarm.repeat.everyDay", colors: colors) { weekdays = [] }
                    quickRepeat("alarm.repeat.weekdays", colors: colors) { weekdays = [1, 2, 3, 4, 5] }
                    quickRepeat("alarm.repeat.weekend", colors: colors) { weekdays = [6, 7] }
                }
                .padding(.top, 10)

                Text(weekdays.isEmpty ? "alarm.repeat.hintEveryDay" : "alarm.repeat.hintSelected")
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .padding(.top, 8)
            }
        }
    }

    private func quickRepeat(
        _ title: LocalizedStringKey,
        colors: AppColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(12, weight: .medium)
                .foregroundStyle(colors.primary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(colors.primaryContainer))
        }
        .buttonStyle(.plain)
    }

    private func optionsCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack {
                Text("alarm.label")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                TextField("alarm.labelPlaceholder", text: $label)
                    .font(AppFont.body)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(colors.onSurface)
            }
            .frame(minHeight: 44)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 2)

            HStack {
                Text("alarm.snooze")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Menu {
                    ForEach([0, 5, 10, 15, 30], id: \.self) { value in
                        Button(value == 0
                            ? String(localized: "alarm.snooze.off")
                            : String(format: String(localized: "alarm.snooze.minutes"), value)) {
                            snoozeMinutes = max(value, 1)
                        }
                    }
                } label: {
                    Text(snoozeMinutes <= 1 && snoozeMinutes != 0
                        ? String(localized: "alarm.snooze.off")
                        : String(format: String(localized: "alarm.snooze.minutes"), snoozeMinutes))
                    .appFont(13, weight: .medium)
                    .foregroundStyle(colors.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(colors.primaryContainer))
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 44)
        }
    }

    // MARK: - Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        time = alarm.time.date(on: .now) ?? .now
        weekdays = Set(alarm.weekdays)
        label = alarm.label
        snoozeMinutes = alarm.snoozeMinutes
    }

    private func save() {
        var saved = alarm
        let clock = TimeOfDay(date: time)
        saved.hour = clock.hour
        saved.minute = clock.minute
        saved.weekdays = weekdays.sorted()
        saved.label = label.trimmingCharacters(in: .whitespaces)
        saved.snoozeMinutes = snoozeMinutes
        if saved.createdAtMillis == 0 {
            saved.createdAtMillis = Int64(Date().timeIntervalSince1970 * 1000)
        }
        onSave(saved)
        dismiss()
    }
}
