import Combine
import CurSimpleCore
import SwiftUI

/// Day timetable with the full today overview card, matching the shared design.
struct DayView: View {

    let term: Term
    let profile: TimingProfile
    let date: Date
    let onOpenCourse: (String) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var now: Date = DayView.debugNow()
    @State private var clockFrozen = ProcessInfo.processInfo.arguments.contains("-todayNow")

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// QA hook: `-todayNow "HH:mm"` freezes the overview clock at that time.
    private static func debugNow() -> Date {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-todayNow"),
              arguments.count > index + 1,
              let time = TimeOfDay(arguments[index + 1]) else {
            return .now
        }
        return time.date(on: .now) ?? .now
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let holidayCalendar = store.state.holidayCalendar
        let overrides = store.state.overrides
        let items = scheduledCourseOccurrencesOn(
            date: date,
            courses: term.courses,
            timingProfile: profile,
            termStartDate: term.startDateValue,
            overrides: overrides,
            holidayCalendar: holidayCalendar,
            calendar: .current
        )
        let resolution = resolveScheduleDay(
            date: date,
            overrides: overrides,
            holidayCalendar: holidayCalendar,
            calendar: .current
        )

        VStack(spacing: 0) {
            dayHeader(
                colors: colors,
                itemCount: items.count,
                remaining: items.filter { item in
                    guard let end = item.end else { return true }
                    return end > now
                }.count
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if resolution.isHoliday {
                        holidayBanner(resolution.holidayName, colors: colors)
                    } else if resolution.isMakeUpWorkday {
                        makeUpBanner(colors: colors)
                    }

                    if Calendar.current.isDateInToday(date) {
                        TodayOverviewCard(items: items, date: date, now: now, colors: colors)
                            .onReceive(timer) { value in
                                if !clockFrozen {
                                    now = value
                                }
                            }
                    }

                    if items.isEmpty {
                        emptyState(colors: colors)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            SettingsSectionLabel(title: "day.schedule.title", colors: colors)
                            timeline(items, colors: colors)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 28)
            }
        }
    }

    private func dayHeader(colors: AppColors, itemCount: Int, remaining: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(date.formatted(.dateTime.month().day()))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(colors.onSurface)
                Text(Format.weekday(ScheduleCalendar.isoDayOfWeek(date)))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(colors.onSurface)
            }
            if Calendar.current.isDateInToday(date) {
                Text(String(
                    format: String(localized: "day.headerCount"),
                    itemCount,
                    remaining
                ))
                .font(AppFont.body)
                .foregroundStyle(colors.onSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func holidayBanner(_ name: String?, colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "tree.fill")
                .font(.system(size: 13))
            Text(name.flatMap { $0.isEmpty ? nil : $0 } ?? String(localized: "day.holiday.generic"))
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(colors.primary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.primaryContainer)
        )
    }

    private func makeUpBanner(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 12))
            Text("day.makeUpWorkday")
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .foregroundStyle(colors.primary)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.primaryContainer.opacity(0.6))
        )
    }

    // MARK: - Timeline (shared "今日安排" style)

    private func timeline(_ items: [ScheduledCourseOccurrence], colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                timelineRow(item, isLast: index == items.count - 1, colors: colors)
            }
        }
        .padding(.leading, 4)
    }

    private func timelineRow(
        _ item: ScheduledCourseOccurrence,
        isLast: Bool,
        colors: AppColors
    ) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let status = rowStatus(item)
        let isCurrent = status == .current

        return HStack(alignment: .top, spacing: 10) {
            // Left clock column
            VStack(spacing: 2) {
                Text(item.start.map { TimeOfDay(date: $0).text } ?? Format.period(item.course.time.startNode))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isCurrent ? colors.primary : colors.onSurface)
                Text(item.end.map { TimeOfDay(date: $0).text } ?? " ")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .frame(width: 54, alignment: .trailing)
            .padding(.top, 14)

            // Dot + rail
            VStack(spacing: 0) {
                Circle()
                    .fill(isCurrent ? colors.primary : Color.clear)
                    .overlay(Circle().stroke(colors.primary, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .padding(.top, 18)
                if !isLast {
                    Rectangle()
                        .fill(colors.outlineVariant)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 16)

            // Status card
            Button {
                onOpenCourse(item.course.id)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(statusTitle(status))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor(status, colors: colors))

                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(colors.onSurface)
                        .lineLimit(2)

                    Text(detailLine(item))
                        .font(.system(size: 13))
                        .foregroundStyle(colors.onSurfaceVariant)
                        .lineLimit(1)

                    if isCurrent, let itemEnd = item.end {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(colors.primary.opacity(0.14))
                                Capsule()
                                    .fill(colors.primary)
                                    .frame(width: max(proxy.size.width * classProgress(item, until: itemEnd), 4))
                            }
                        }
                        .frame(height: 5)
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isCurrent ? colors.primaryContainer : colors.surfaceVariant.opacity(0.55))
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, isLast ? 0 : 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private enum RowStatus {
        case current, pending, done, untimed
    }

    private func rowStatus(_ item: ScheduledCourseOccurrence) -> RowStatus {
        guard let start = item.start, let end = item.end else { return .untimed }
        if !Calendar.current.isDateInToday(date) {
            // Past days are done; future days are pending; a frozen clock
            // (-todayNow) evaluates against the displayed day's wall clock.
            if clockFrozen {
                let dayStart = TimeOfDay(date: start)
                let dayEnd = TimeOfDay(date: end)
                let clock = TimeOfDay(date: now)
                if clock >= dayStart && clock < dayEnd { return .current }
                if clock >= dayEnd { return .done }
                return .pending
            }
            return date < .now ? .done : .pending
        }
        if now >= start && now < end { return .current }
        if now >= end { return .done }
        return .pending
    }

    private func statusTitle(_ status: RowStatus) -> String {
        switch status {
        case .current: String(localized: "day.status.current")
        case .pending: String(localized: "day.status.pending")
        case .done: String(localized: "day.status.done")
        case .untimed: String(localized: "day.status.untimed")
        }
    }

    private func statusColor(_ status: RowStatus, colors: AppColors) -> Color {
        switch status {
        case .current: colors.primary
        case .pending: Color(red: 0.30, green: 0.55, blue: 0.30)
        case .done: colors.onSurfaceVariant
        case .untimed: colors.onSurfaceVariant
        }
    }

    private func detailLine(_ item: ScheduledCourseOccurrence) -> String {
        var parts: [String] = []
        if let start = item.start, let end = item.end {
            parts.append("\(TimeOfDay(date: start).text)-\(TimeOfDay(date: end).text)")
        }
        if !item.location.isEmpty { parts.append(item.location) }
        if !item.teacher.isEmpty { parts.append(item.teacher) }
        if parts.isEmpty {
            parts.append(Format.periodRange(item.course.time.startNode, item.course.time.endNode))
        }
        return parts.joined(separator: " · ")
    }

    private func classProgress(_ item: ScheduledCourseOccurrence, until end: Date) -> Double {
        guard let start = item.start, end > start else { return 0 }
        return min(max(now.timeIntervalSince(start) / end.timeIntervalSince(start), 0), 1)
    }

    private func emptyState(colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 24))
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))

            Text("day.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
            Text("day.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Today state

private struct TodayState {
    let timed: [ScheduledCourseOccurrence]
    let current: ScheduledCourseOccurrence?
    let next: ScheduledCourseOccurrence?
    let doneCount: Int
    let unknownTimeCount: Int
    let nowValue: Date?

    init(items: [ScheduledCourseOccurrence], now: Date) {
        timed = items.filter(\.hasTime)
        current = timed.first { $0.start! <= now && $0.end! > now }
        next = timed.first { $0.start! > now }
        doneCount = timed.filter { $0.end! <= now }.count
        unknownTimeCount = items.filter { !$0.hasTime }.count
        nowValue = now
    }

    var total: Int { timed.count }

    /// 0...1 progress through the current class.
    var currentProgress: Double {
        guard let current, let now = nowValue else { return 0 }
        let total = current.end!.timeIntervalSince(current.start!)
        guard total > 0 else { return 0 }
        return min(max(now.timeIntervalSince(current.start!) / total, 0), 1)
    }

    var statusTitleKey: LocalizedStringKey {
        if current != nil { return "today.status.current" }
        if next != nil { return "today.status.next" }
        if unknownTimeCount > 0 { return "today.status.needTiming" }
        if total == 0 { return "today.status.empty" }
        return "today.status.finished"
    }

    var countdownText: String? {
        if let current, let now = nowValue {
            let seconds = Int(ceil(current.end!.timeIntervalSince(now)))
            if seconds < 3600 {
                return String(
                    format: String(localized: "today.secondsToEnd"),
                    seconds / 60,
                    seconds % 60
                )
            }
            return String(format: String(localized: "today.minutesToEnd"), Int(ceil(Double(seconds) / 60)))
        }
        if let next, let now = nowValue {
            let seconds = Int(ceil(next.start!.timeIntervalSince(now)))
            if seconds < 3600 {
                return String(
                    format: String(localized: "today.secondsToStart"),
                    seconds / 60,
                    seconds % 60
                )
            }
            let minutes = Int(ceil(Double(seconds) / 60))
            if minutes < 60 {
                return String(format: String(localized: "today.minutesToEnd"), minutes)
            }
            return String(
                format: String(localized: "today.hoursToStart"),
                minutes / 60,
                minutes % 60
            )
        }
        return nil
    }
}

// MARK: - Overview card

private struct TodayOverviewCard: View {

    let items: [ScheduledCourseOccurrence]
    let date: Date
    let now: Date
    let colors: AppColors

    @State private var appeared = false

    private var state: TodayState {
        TodayState(items: items, now: now)
    }

    var body: some View {
        let state = state
        let active = state.current != nil
        let container = active ? colors.primaryContainer : colors.surfaceVariant
        let content = active ? colors.onPrimaryContainer : colors.onSurface
        let muted = content.opacity(0.72)
        let focus = state.current ?? state.next

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                progressRing(state, content: content)

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.statusTitleKey)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.primary)

                    if let focus {
                        Text(focus.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(content)
                            .lineLimit(1)

                        Text(occurrenceInfo(focus))
                            .font(AppFont.bodySmall)
                            .foregroundStyle(muted)
                            .lineLimit(1)
                    } else {
                        Text(moodLine(for: state, date: date))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(content)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            if let current = state.current {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(content.opacity(0.12))
                        Capsule()
                            .fill(colors.primary)
                            .frame(width: max(proxy.size.width * currentProgress(animated: appeared, value: state.currentProgress), 8))
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: 8) {
                if let countdown = state.countdownText {
                    chip(countdown, fill: colors.primary.opacity(0.14), text: colors.primary)
                }
                if let next = state.next, state.current != nil {
                    Text(String(
                        format: String(localized: "today.nextBrief"),
                        next.title,
                        TimeOfDay(date: next.start!).text
                    ))
                    .font(AppFont.bodySmall)
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(container)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }

    /// Idle-state line picked by the shared day-mood rules; falls back to the count line.
    private func moodLine(for state: TodayState, date: Date) -> String {
        let calendar = Calendar.current
        let context = DayMoodContext(
            date: date,
            hour: calendar.component(.hour, from: now),
            isoWeekday: ScheduleCalendar.isoDayOfWeek(date, calendar: calendar),
            totalCourses: state.total
        )
        if let mood = dayMood(for: context) {
            let lines = moodLines(for: mood, locale: Locale.current.identifier)
            let index = dayMoodLineIndex(date: date, mood: mood, size: lines.count, calendar: calendar)
            return lines[index]
        }
        return String(
            format: String(localized: "today.count"),
            state.total,
            max(state.total - state.doneCount, 0)
        )
    }

    private func currentProgress(animated: Bool, value: Double) -> Double {
        animated ? value : 0
    }

    // MARK: Progress ring

    private func progressRing(_ state: TodayState, content: Color) -> some View {
        let total = max(state.total, 1)
        let fraction = Double(state.doneCount) / Double(total)
        let animatedFraction = appeared ? fraction : 0

        return ZStack {
            Circle()
                .stroke(content.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(colors.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            HStack(alignment: .bottom, spacing: 0) {
                Text("\(state.doneCount)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(content)
                Text("/\(total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(content.opacity(0.7))
                    .padding(.bottom, 2)
            }
        }
        .frame(width: 56, height: 56)
        .accessibilityLabel(String(
            format: String(localized: "today.progressDesc"),
            state.doneCount,
            total
        ))
    }

    private func chip(_ text: String, fill: Color, text color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(fill))
    }

    private func occurrenceInfo(_ item: ScheduledCourseOccurrence) -> String {
        var parts: [String] = []
        if let start = item.start, let end = item.end {
            parts.append("\(TimeOfDay(date: start).text)–\(TimeOfDay(date: end).text)")
        } else {
            parts.append(String(localized: "today.timeMissing"))
        }
        if !item.location.isEmpty { parts.append(item.location) }
        if !item.teacher.isEmpty { parts.append(item.teacher) }
        return parts.joined(separator: " · ")
    }
}
