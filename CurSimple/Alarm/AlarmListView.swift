import CurSimpleCore
import SwiftUI

/// Manual alarms, mirroring the shared "闹钟" tab: large next-alarm summary,
/// alarm rows with weekday summary and a floating add button.
struct AlarmListView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(ReminderService.self) private var reminders
    @Environment(\.colorScheme) private var colorScheme

    @State private var editingAlarm: Alarm? = ProcessInfo.processInfo.arguments.contains("-openAlarmEditor")
        ? Alarm(createdAtMillis: 1)
        : nil
    @State private var now = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let alarms = store.alarmsSorted(now: now)

        ZStack(alignment: .bottomTrailing) {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("alarm.pageTitle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)

                    HStack {
                        Button(action: onOpenDrawer) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(colors.onBackground)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("drawer.open")
                        Spacer()
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        if !reminders.isAuthorized {
                            permissionCard(colors: colors)
                        }

                        if let next = alarms.first(where: \.enabled),
                           let fire = nextAlarmFires(next, after: now, count: 1).first {
                            nextCard(alarm: next, fire: fire, colors: colors)
                        }

                        if alarms.isEmpty {
                            emptyState(colors: colors)
                        } else {
                            ForEach(alarms) { alarm in
                                alarmRow(alarm, colors: colors)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 96)
                }
            }

            addButton(colors: colors)
                .padding(.trailing, 18)
                .padding(.bottom, 14)
        }
        .onReceive(timer) { now = $0 }
        .sheet(item: $editingAlarm) { alarm in
            AlarmEditorView(alarm: alarm) { saved in
                store.upsertAlarm(saved)
                Task { await reminders.rescheduleAlarms(store: store) }
            } onDelete: {
                store.deleteAlarm(id: alarm.id)
                Task { await reminders.rescheduleAlarms(store: store) }
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Pieces

    private func nextCard(alarm: Alarm, fire: Date, colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("alarm.next")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.onPrimaryContainer.opacity(0.75))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(alarm.time.text)
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                    .foregroundStyle(colors.onPrimaryContainer)
                Text(relativeTime(fire))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(colors.onPrimaryContainer.opacity(0.8))
                Spacer()
            }

            Text(alarm.displayLabel)
                .font(.system(size: 13))
                .foregroundStyle(colors.onPrimaryContainer.opacity(0.75))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colors.primaryContainer)
        )
    }

    private func permissionCard(colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 14))
                .foregroundStyle(colors.error)
            Text("alarm.permissionNeeded")
                .font(.system(size: 12))
                .foregroundStyle(colors.onSurfaceVariant)
            Spacer()
            Button {
                Task { await reminders.requestAuthorization() }
            } label: {
                Text("alarm.enable")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func alarmRow(_ alarm: Alarm, colors: AppColors) -> some View {
        HStack(spacing: 12) {
            Button {
                editingAlarm = alarm
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(alarm.time.text)
                            .font(.system(size: 30, weight: .semibold).monospacedDigit())
                            .foregroundStyle(alarm.enabled ? colors.onSurface : colors.onSurfaceVariant)
                        Text(repeatText(alarm))
                            .font(.system(size: 12))
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                    Text(alarm.displayLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { alarm.enabled },
                set: { value in
                    store.setAlarmEnabled(id: alarm.id, enabled: value)
                    Task { await reminders.rescheduleAlarms(store: store) }
                }
            ))
            .labelsHidden()
            .tint(colors.primary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func addButton(colors: AppColors) -> some View {
        Button {
            editingAlarm = Alarm(createdAtMillis: Int64(Date().timeIntervalSince1970 * 1000))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("alarm.addShort")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(colors.onPrimaryContainer)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(Capsule().fill(colors.primaryContainer))
            .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("alarm.add")
    }

    private func emptyState(colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "alarm")
                .font(.system(size: 24))
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))
            Text("alarm.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
            Text("alarm.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Text

    private func repeatText(_ alarm: Alarm) -> String {
        switch alarmRepeatSummary(alarm) {
        case .everyDay: return String(localized: "alarm.repeat.everyDay")
        case .weekdays: return String(localized: "alarm.repeat.weekdays")
        case .weekend: return String(localized: "alarm.repeat.weekend")
        case .specific(let days):
            return days.map { Format.weekdayNarrow($0) }.joined(separator: " ")
        }
    }

    private func relativeTime(_ fire: Date) -> String {
        let seconds = max(0, fire.timeIntervalSince(now))
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 {
            return String(format: String(localized: "alarm.inMinutes"), minutes)
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(format: String(localized: "alarm.inHours"), hours)
        }
        let days = hours / 24
        return String(format: String(localized: "alarm.inDays"), days)
    }
}
