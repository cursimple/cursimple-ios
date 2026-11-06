import CurSimpleCore
import SwiftUI

/// Week timetable: fixed day header, scrollable period grid, course cards.
struct WeekGridView: View {

    let term: Term
    let profile: TimingProfile
    let preferences: AppPreferences
    let displayWeekStart: Date
    let onTapCourse: (String) -> Void
    let onLongPressCourse: (String) -> Void
    let onTapEmpty: (CourseTimeSlot) -> Void
    let onSelectDay: (Date) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var overlapCluster: GridCourseCluster?

    private let gutterWidth: CGFloat = 42
    private let rowHeight: CGFloat = 64
    private let innerPadding: CGFloat = 8

    var body: some View {
        let colors = AppColors.resolve(accent: preferences.accent, dark: colorScheme == .dark)

        GeometryReader { proxy in
            let columnWidth = max((proxy.size.width - innerPadding * 2 - gutterWidth) / CGFloat(days.count), 34)

            VStack(spacing: 0) {
                headerRow(columnWidth: columnWidth, colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        timeGutter(colors: colors)
                        ForEach(days, id: \.self) { day in
                            dayColumn(day: day, width: columnWidth, colors: colors)
                        }
                    }
                    .padding(.bottom, 28)
                }
            }
            .padding(.horizontal, innerPadding)
        }
        .confirmationDialog(
            "schedule.overlap.title",
            isPresented: Binding(
                get: { overlapCluster != nil },
                set: { if !$0 { overlapCluster = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(overlapCluster?.courses ?? []) { course in
                Button("\(course.title) · \(Format.periodRange(course.time.startNode, course.time.endNode))") {
                    overlapCluster = nil
                    onTapCourse(course.id)
                }
            }
            Button("common.cancel", role: .cancel) { overlapCluster = nil }
        }
    }

    // MARK: - Derived

    private var days: [Int] {
        columnDayOfWeeks(
            weekStart: preferences.weekStart,
            showWeekend: preferences.showWeekend,
            showSaturday: preferences.showSaturday
        )
    }

    private var weekNumber: Int? {
        guard let start = term.startDateValue else { return nil }
        return displayWeekTermIndex(termStart: start, displayWeekStart: displayWeekStart)
    }

    private var nodeCount: Int {
        weekGridNodeCount(profile: profile, courses: term.courses)
    }

    private var dayContents: [Int: DayGridContent] {
        Dictionary(uniqueKeysWithValues: days.map { day in
            let date = self.date(for: day)
            let content = dayGridContent(
                date: date,
                courses: term.courses,
                overrides: store.state.overrides,
                holidayCalendar: store.state.holidayCalendar,
                termStartDate: term.startDateValue
            )
            return (day, content)
        })
    }

    private func date(for day: Int) -> Date {
        columnDate(
            displayWeekStart: displayWeekStart,
            dayOfWeek: day,
            weekStart: preferences.weekStart
        )
    }

    // MARK: - Header

    private func headerRow(columnWidth: CGFloat, colors: AppColors) -> some View {
        HStack(spacing: 0) {
            monthLabel(colors: colors)
                .frame(width: gutterWidth, height: 58, alignment: .leading)

            ForEach(days, id: \.self) { day in
                let dayDate = date(for: day)
                let today = Calendar.current.isDateInToday(dayDate)

                Button {
                    onSelectDay(dayDate)
                } label: {
                    VStack(spacing: 1) {
                        Text(Format.weekdayNarrow(day))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(
                                today ? colors.todayOnContainer.opacity(0.82) : colors.onSurfaceVariant
                            )
                        Text("\(Calendar.current.component(.day, from: dayDate))")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(today ? colors.todayOnContainer : colors.onSurface)
                    }
                    .frame(width: columnWidth, height: 52)
                    .background {
                        if today {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colors.todayContainer)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func monthLabel(colors: AppColors) -> some View {
        let month = Calendar.current.component(.month, from: displayWeekStart)
        let unit = String(localized: "schedule.monthUnit")

        return VStack(alignment: .leading, spacing: -1) {
            if unit.isEmpty {
                Text(displayWeekStart.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 16, weight: .bold))
            } else {
                Text("\(month)")
                    .font(.system(size: 21, weight: .bold))
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundStyle(colors.onSurface)
    }

    // MARK: - Grid

    private func timeGutter(colors: AppColors) -> some View {
        VStack(spacing: 0) {
            ForEach(1...nodeCount, id: \.self) { node in
                VStack(spacing: 0) {
                    Text(String(format: String(localized: "schedule.periodCompact"), node))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(colors.onSurface)
                    if let slot = profile.slot(startingAt: node), let start = slot.start, let end = slot.end {
                        Text(start.text)
                            .font(.system(size: 10))
                            .foregroundStyle(colors.onSurfaceVariant)
                        Text(end.text)
                            .font(.system(size: 10))
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                }
                .frame(width: gutterWidth, height: rowHeight)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(colors.gridLine)
                        .frame(height: 0.5)
                }
            }
        }
    }

    private func dayColumn(day: Int, width: CGFloat, colors: AppColors) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(1...nodeCount, id: \.self) { node in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: width, height: rowHeight)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(colors.gridLine)
                                .frame(height: 0.5)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapEmpty(CourseTimeSlot(dayOfWeek: day, startNode: node, endNode: node))
                        }
                }
            }

            if let content = dayContents[day] {
                ForEach(content.clusters) { cluster in
                    clusterCard(cluster, columnWidth: width, colors: colors)
                }
                if content.isHoliday {
                    Rectangle()
                        .fill(colors.surface.opacity(0.55))
                        .frame(width: width, height: CGFloat(nodeCount) * rowHeight)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    private func clusterCard(
        _ cluster: GridCourseCluster,
        columnWidth: CGFloat,
        colors: AppColors
    ) -> some View {
        let course = cluster.primary
        let entry = CoursePalette.courseEntry(
            for: course,
            style: preferences.paletteStyle,
            dark: colorScheme == .dark
        )
        let span = course.time.nodeRange.count
        let height = CGFloat(span) * rowHeight - 4
        let showLocation = span > 1 && !course.location.isEmpty && height > 74

        return ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(course.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(entry.onContainer.color)
                    .lineLimit(span > 1 ? 5 : 3)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.75)

                if showLocation {
                    Text("@\(course.location)")
                        .font(.system(size: 8.5))
                        .foregroundStyle(entry.onContainer.color.opacity(0.72))
                        .lineLimit(3)
                }

                Spacer(minLength: 0)
            }
            .padding(5)
            .frame(width: columnWidth - 4, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(entry.container.color)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture { onTapCourse(course.id) }
            .onLongPressGesture(minimumDuration: 0.45) { onLongPressCourse(course.id) }

            if cluster.count > 1 {
                Button {
                    overlapCluster = cluster
                } label: {
                    HStack(spacing: 2) {
                        Text(String(
                            format: String(localized: "schedule.overlap.count"),
                            cluster.count
                        ))
                        Image(systemName: "ellipsis")
                    }
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 17)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(Capsule().fill(colors.surface.opacity(0.94)))
                    .padding(5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("schedule.overlap.title")
            }
        }
        .frame(width: columnWidth, height: height, alignment: .topLeading)
        .offset(
            x: 2,
            y: CGFloat(course.time.startNode - 1) * rowHeight + 2
        )
        .accessibilityElement(children: .contain)
    }
}
