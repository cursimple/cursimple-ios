import CurSimpleCore
import SwiftUI
import UIKit

struct ReminderSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var enabled = false
    @State private var advanceMinutes = 45
    @State private var includeExams = true
    @State private var working = false
    @State private var loaded = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                SettingsHeader(title: "reminder.pageTitle", colors: colors, onBack: { dismiss() })

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        masterCard(colors: colors)
                        advanceCard(colors: colors)
                        optionsCard(colors: colors)
                        statusCard(colors: colors)
                        policyCard(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await reminders.refreshStatus()
            load()
        }
        .onAppear(perform: load)
    }

    // MARK: - Cards

    private func masterCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .appFont(17, weight: .medium)
                    .foregroundStyle(colors.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(colors.primaryContainer))

                VStack(alignment: .leading, spacing: 2) {
                    Text("reminder.enabled")
                        .appFont(15, weight: .semibold)
                        .foregroundStyle(colors.onSurface)
                    Text("reminder.enabled.footer")
                        .font(AppFont.label)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .tint(colors.primary)
                    .accessibilityIdentifier("reminder-master-toggle")
                    .onChange(of: enabled) { _, value in
                        guard loaded else { return }
                        Task { await setEnabled(value) }
                    }
            }
        }
    }

    private func advanceCard(colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(title: "reminder.advance", colors: colors)

            SettingsCard(colors: colors) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(ReminderPreferences.advanceOptions, id: \.self) { minutes in
                        let selected = advanceMinutes == minutes
                        Button {
                            advanceMinutes = minutes
                            save()
                        } label: {
                            Text(advanceLabel(minutes))
                                .appFont(12, weight: .semibold)
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
            }
        }
    }

    private func optionsCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Toggle(isOn: $includeExams) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("reminder.includeExams")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Text("reminder.includeExams.footer")
                        .font(AppFont.label)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
            .tint(colors.primary)
            .onChange(of: includeExams) { _, _ in
                guard loaded else { return }
                save()
            }
        }
    }

    private func statusCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack {
                Text("reminder.permission")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Text(reminders.statusTextKey)
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(reminders.permissionDenied ? colors.error : colors.primary)
                    .accessibilityIdentifier("reminder-permission-status")
            }
            .frame(minHeight: 36)

            Divider().overlay(colors.outlineVariant).padding(.vertical, 4)

            HStack {
                Text("reminder.scheduled")
                    .font(AppFont.body)
                    .foregroundStyle(colors.onSurface)
                Spacer()
                Text(String(format: String(localized: "reminder.scheduled.count"), reminders.scheduledCount))
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .accessibilityIdentifier("reminder-scheduled-count")
            }
            .frame(minHeight: 36)

            if reminders.permissionDenied {
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("reminder.permission.openSettings")
                        Spacer()
                    }
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            Button {
                Task {
                    working = true
                    await reminders.reschedule(store: store)
                    working = false
                }
            } label: {
                HStack {
                    if working {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("reminder.reschedule")
                    Spacer()
                }
                .appFont(13, weight: .medium)
                .foregroundStyle(colors.primary)
            }
            .buttonStyle(.plain)
            .disabled(working)
            .padding(.top, 6)
        }
    }

    private func policyCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text(String(
                format: String(localized: "reminder.scheduled.footer"),
                store.preferences.reminders.normalized.horizonDays
            ))
            .font(AppFont.label)
            .foregroundStyle(colors.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - State

    private func load() {
        guard !loaded else { return }
        let preferences = store.preferences.reminders.normalized
        enabled = preferences.enabled
        advanceMinutes = preferences.advanceMinutes
        includeExams = preferences.includeExams
        loaded = true
    }

    private func setEnabled(_ value: Bool) async {
        if value {
            let granted = await reminders.requestAuthorization()
            if !granted {
                enabled = false
                return
            }
        }
        save()
    }

    private func save() {
        var preferences = store.preferences
        preferences.reminders.enabled = enabled
        preferences.reminders.advanceMinutes = advanceMinutes
        preferences.reminders.includeExams = includeExams
        store.setPreferences(preferences)
        Task { await reminders.reschedule(store: store) }
    }

    private func advanceLabel(_ minutes: Int) -> String {
        if minutes == 0 { return String(localized: "reminder.advance.atStart") }
        return String(format: String(localized: "reminder.advance.minutes"), minutes)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
