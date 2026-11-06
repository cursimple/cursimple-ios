import CurSimpleCore
import Foundation
import SwiftUI
import Observation
import UserNotifications

/// Schedules class reminders as local notifications.
///
/// iOS keeps at most 64 pending requests, so the planner only covers a short
/// rolling window and the list is rebuilt whenever the app becomes active or
/// the schedule changes.
@MainActor
@Observable
final class ReminderService {

    static let shared = ReminderService()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0
    private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "cursimple.class."

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        await refreshScheduledCount()
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            lastError = error.localizedDescription
        }
        await refreshStatus()
        return isAuthorized
    }

    func reschedule(store: AppStore) async {
        await refreshStatus()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }

        let preferences = store.preferences.reminders.normalized
        guard preferences.enabled,
              isAuthorized,
              let term = store.activeTerm else {
            await refreshScheduledCount()
            return
        }

        let reminders = plannedReminders(
            term: term,
            profile: store.timingProfile,
            preferences: preferences,
            now: .now
        )

        for reminder in reminders {
            let interval = reminder.fireAt.timeIntervalSinceNow
            guard interval > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = notificationTitle(reminder)
            content.body = notificationBody(reminder, advanceMinutes: preferences.advanceMinutes)
            content.sound = .default
            content.userInfo = ["courseID": reminder.course.id]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + reminder.id,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                lastError = error.localizedDescription
            }
        }

        await refreshScheduledCount()
    }

    func cancelAll() {
        let center = self.center
        Task {
            let pending = await center.pendingNotificationRequests()
            let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            await refreshScheduledCount()
        }
    }

    // MARK: - Content

    private func notificationTitle(_ reminder: PlannedReminder) -> String {
        String(
            format: String(localized: "reminder.notification.title"),
            reminder.title,
            TimeOfDay(date: reminder.start).text
        )
    }

    private func notificationBody(_ reminder: PlannedReminder, advanceMinutes: Int) -> String {
        let lead = advanceMinutes > 0
            ? String(format: String(localized: "reminder.notification.inMinutes"), advanceMinutes)
            : String(localized: "reminder.notification.now")

        var details: [String] = []
        if !reminder.location.isEmpty { details.append(reminder.location) }
        if !reminder.teacher.isEmpty { details.append(reminder.teacher) }
        if details.isEmpty {
            details.append(Format.periodRange(
                reminder.course.time.startNode,
                reminder.course.time.endNode
            ))
        }
        return "\(lead) · \(details.joined(separator: " · "))"
    }

    private func refreshScheduledCount() async {
        let pending = await center.pendingNotificationRequests()
        scheduledCount = pending.filter { $0.identifier.hasPrefix(identifierPrefix) }.count
    }

    // MARK: - Presentation helpers

    var statusTextKey: LocalizedStringKey {
        switch authorizationStatus {
        case .authorized: "reminder.permission.authorized"
        case .provisional: "reminder.permission.provisional"
        case .denied: "reminder.permission.denied"
        case .ephemeral: "reminder.permission.provisional"
        case .notDetermined: "reminder.permission.notDetermined"
        @unknown default: "reminder.permission.notDetermined"
        }
    }

    var permissionDenied: Bool {
        authorizationStatus == .denied
    }
}
