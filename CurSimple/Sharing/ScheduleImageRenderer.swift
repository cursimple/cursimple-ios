import CurSimpleCore
import SwiftUI

/// Off-screen renderer for the "share timetable as an image" feature.
/// Uses the same grid geometry as the week view so the picture matches the app.
enum ScheduleImageRenderer {

    static let width: CGFloat = 1080

    @MainActor
    static func render(
        term: Term,
        profile: TimingProfile,
        preferences: AppPreferences,
        holidayCalendar: HolidayCalendarSettings,
        overrides: [TemporaryScheduleOverride],
        weekStart: Date,
        weekNumber: Int,
        dark: Bool,
        calendar: Calendar = .current
    ) -> UIImage? {
        let colors = AppColors.resolve(accent: preferences.accent, dark: dark)
        let days = columnDays(preferences: preferences)
        let view = ScheduleImageContent(
            term: term,
            profile: profile,
            preferences: preferences,
            holidayCalendar: holidayCalendar,
            overrides: overrides,
            weekStart: weekStart,
            weekNumber: weekNumber,
            days: days,
            colors: colors,
            dark: dark
        )
        .frame(width: width)
        .background(colors.background)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return renderer.uiImage
    }

    private static func columnDays(preferences: AppPreferences) -> [Int] {
        columnDayOfWeeks(
            weekStart: preferences.weekStart,
            showWeekend: preferences.showWeekend,
            showSaturday: preferences.showSaturday
        )
    }
}

// MARK: - Content

private struct ScheduleImageContent: View {

    let term: Term
    let profile: TimingProfile
    let preferences: AppPreferences
    let holidayCalendar: HolidayCalendarSettings
    let overrides: [TemporaryScheduleOverride]
    let weekStart: Date
    let weekNumber: Int
    let days: [Int]
    let colors: AppColors
    let dark: Bool

    private var rowHeight: CGFloat { CGFloat(preferences.display.cardHeight) }
    private let gutterWidth: CGFloat = 76
    private let headerHeight: CGFloat = 92

    var body: some View {
        VStack(spacing: 0) {
            header
            grid
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(term.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(colors.onSurface)
                Text(weekLabel)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colors.primary)
            }
            Spacer()
            Text("app.name")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(height: headerHeight + 28, alignment: .center)
    }

    private var weekLabel: String {
        weekNumber >= 1
            ? String(format: String(localized: "week.number"), weekNumber)
            : String(localized: "week.notStarted")
    }

    private var nodeCount: Int {
        weekGridNodeCount(profile: profile, courses: term.courses)
    }

    private var grid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: gutterWidth, height: 40)
                ForEach(days, id: \.self) { day in
                    let date = columnDate(
                        displayWeekStart: weekStart,
                        dayOfWeek: day,
                        weekStart: preferences.weekStart
                    )
                    let content = dayContent(date)
                    VStack(spacing: 1) {
                        Text(content.isHoliday ? "休" : Format.weekdayNarrow(day))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(content.isHoliday ? colors.primary : colors.onSurfaceVariant)
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(content.isHoliday ? colors.onSurfaceVariant : colors.onSurface)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
            }

            ForEach(1...nodeCount, id: \.self) { node in
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("\(node)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(colors.onSurface)
                        if let slot = profile.slot(startingAt: node), let start = slot.start {
                            Text(start.text)
                                .font(.system(size: 11))
                                .foregroundStyle(colors.onSurfaceVariant)
                        }
                    }
                    .frame(width: gutterWidth, height: rowHeight)
                    .overlay(alignment: .bottom) {
                        if preferences.display.gridStyle != .none {
                            Rectangle().fill(colors.gridLine).frame(height: 0.5)
                        }
                    }

                    ForEach(days, id: \.self) { day in
                        cell(day: day, node: node)
                            .frame(maxWidth: .infinity, minHeight: rowHeight)
                            .overlay(alignment: .bottom) {
                                if preferences.display.gridStyle != .none {
                                    Rectangle().fill(colors.gridLine).frame(height: 0.5)
                                }
                            }
                    }
                }
            }
        }
    }

    private func cell(day: Int, node: Int) -> some View {
        let date = columnDate(
            displayWeekStart: weekStart,
            dayOfWeek: day,
            weekStart: preferences.weekStart
        )
        let content = dayContent(date)
        let blocks = content.clusters.flatMap { cluster in
            cluster.courses.filter { $0.time.nodeRange.lowerBound == node }
        }

        return ZStack(alignment: .topLeading) {
            Color.clear

            if content.isHoliday {
                colors.surfaceVariant.opacity(0.4)
            }

            VStack(spacing: 2) {
                ForEach(blocks) { course in
                    courseChip(course)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 1)
        }
    }

    private func courseChip(_ course: CourseItem) -> some View {
        let entry = CoursePalette.courseEntry(
            for: course,
            style: preferences.paletteStyle,
            dark: dark
        )
        return VStack(alignment: .leading, spacing: 1) {
            Text(course.title)
                .font(.system(size: CGFloat(preferences.display.textSize), weight: .semibold))
                .foregroundStyle(entry.onContainer.color)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
            if !course.location.isEmpty {
                Text("@\(course.location)")
                    .font(.system(size: CGFloat(max(preferences.display.textSize - 3, 8))))
                    .foregroundStyle(entry.onContainer.color.opacity(0.72))
                    .lineLimit(2)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat(preferences.display.cornerRadius), style: .continuous)
                .fill(entry.container.color.opacity(preferences.display.cardOpacity))
        )
    }

    private func dayContent(_ date: Date) -> DayGridContent {
        dayGridContent(
            date: date,
            courses: term.courses,
            overrides: overrides,
            holidayCalendar: holidayCalendar,
            termStartDate: term.startDateValue
        )
    }
}
