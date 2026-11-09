import CurSimpleCore
import SwiftUI

/// Month calendar used to jump to a week, matching the shared week picker.
struct WeekPickerSheet: View {

    let term: Term
    let currentWeekStart: Date
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var month: Date

    init(term: Term, currentWeekStart: Date, onPick: @escaping (Date) -> Void) {
        self.term = term
        self.currentWeekStart = currentWeekStart
        self.onPick = onPick
        _month = State(initialValue: currentWeekStart)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    var body: some View {
        let colors = AppColors.resolve(accent: .green, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header(colors)
                weekdayHeader(colors)
                grid(colors)
                weekList(colors)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Chrome

    private func header(_ colors: AppColors) -> some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(colors.primaryContainer))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(month.formatted(.dateTime.year().month(.wide)))
                    .appFont(17, weight: .semibold)
                    .foregroundStyle(colors.onSurface)
                Text(weekRangeText)
                    .appFont(11)
                    .foregroundStyle(colors.onSurfaceVariant)
            }

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(colors.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(colors.primaryContainer))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 14)
    }

    private func weekdayHeader(_ colors: AppColors) -> some View {
        HStack(spacing: 0) {
            ForEach(1...7, id: \.self) { day in
                Text(Format.weekdayNarrow(day))
                    .appFont(11, weight: .medium)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 6)
    }

    private func grid(_ colors: AppColors) -> some View {
        let days = monthGrid()
        let rows = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

        return VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        dayCell(date, colors)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date?, _ colors: AppColors) -> some View {
        Group {
            if let date {
                let inWeek = isInCurrentWeek(date)
                let inTerm = isInTerm(date)
                Button {
                    onPick(ScheduleCalendar.startOfDisplayWeek(containing: date, weekStart: .monday))
                    dismiss()
                } label: {
                    VStack(spacing: 1) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 13, weight: inWeek ? .bold : .regular))
                            .foregroundStyle(
                                inWeek ? colors.onPrimary
                                    : (inTerm ? colors.onSurface : colors.onSurfaceVariant.opacity(0.45))
                            )
                        if let week = weekNumber(date), inTerm {
                            Text("\(week)")
                                .appFont(8)
                                .foregroundStyle(inWeek ? colors.onPrimary.opacity(0.8) : colors.primary.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(inWeek ? colors.primary : .clear)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(maxWidth: .infinity, minHeight: 40)
            }
        }
    }

    private func weekList(_ colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionLabel(title: "weekPicker.jump", colors: colors)
                .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weeksInTerm(), id: \.self) { week in
                        let start = weekStart(week)
                        let selected = start.map { calendar.isDate($0, inSameDayAs: currentWeekStart) } ?? false
                        Button {
                            if let start {
                                onPick(start)
                                dismiss()
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Text(String(format: String(localized: "week.number"), week))
                                    .appFont(12, weight: .semibold)
                                if let start {
                                    Text(Format.monthDay(start))
                                        .appFont(9)
                                        .opacity(0.75)
                                }
                            }
                            .foregroundStyle(selected ? colors.onPrimary : colors.onSurface)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? colors.primary : colors.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Dates

    private var weekRangeText: String {
        let end = ScheduleCalendar.addDays(6, to: currentWeekStart)
        return "\(Format.monthDay(currentWeekStart)) – \(Format.monthDay(end))"
    }

    private func shiftMonth(_ delta: Int) {
        month = calendar.date(byAdding: .month, value: delta, to: month) ?? month
    }

    /// Six weeks starting on the Monday of the month's first week.
    private func monthGrid() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let first = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: first) else {
            return []
        }
        let leading = (ScheduleCalendar.isoDayOfWeek(first, calendar: calendar) + 6) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<range.count {
            days.append(ScheduleCalendar.addDays(offset, to: first, calendar: calendar))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func isInCurrentWeek(_ date: Date) -> Bool {
        let start = ScheduleCalendar.startOfDisplayWeek(containing: date, weekStart: .monday, calendar: calendar)
        return calendar.isDate(start, inSameDayAs: currentWeekStart)
    }

    private func isInTerm(_ date: Date) -> Bool {
        guard let week = weekNumber(date) else { return false }
        return week >= 1 && week <= term.weekCount
    }

    private func weekNumber(_ date: Date) -> Int? {
        guard let start = term.startDateValue else { return nil }
        return ScheduleCalendar.teachingWeekNumber(termStart: start, date: date, calendar: calendar)
    }

    private func weeksInTerm() -> [Int] {
        Array(1...max(term.weekCount, 1))
    }

    private func weekStart(_ week: Int) -> Date? {
        guard let start = term.startDateValue else { return nil }
        let termMonday = ScheduleCalendar.startOfTeachingWeek(containing: start, calendar: calendar)
        return ScheduleCalendar.addWeeks(week - 1, to: termMonday, calendar: calendar)
    }
}
