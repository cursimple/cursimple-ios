import CurSimpleCore
import SwiftUI

struct ScheduleView: View {

    @Environment(AppStore.self) private var store

    @State private var displayWeekStart: Date = ScheduleCalendar.startOfDisplayWeek(containing: .now, weekStart: .monday)
    @State private var viewMode: ScheduleViewMode = .week
    @State private var editingCourse: CourseItem?
    @State private var isAddingCourse = false
    @State private var detailCourseID: String?
    @State private var showTermPicker = false

    private var preferences: AppPreferences { store.preferences }
    private var term: Term? { store.activeTerm }

    var body: some View {
        NavigationStack {
            Group {
                if let term {
                    scheduleContent(term: term)
                } else {
                    ContentUnavailableView(
                        "schedule.noTerm.title",
                        systemImage: "calendar.badge.plus",
                        description: Text("schedule.noTerm.message")
                    )
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $editingCourse) { course in
                CourseEditorView(
                    editing: course.id.isEmpty ? nil : course,
                    initialSlot: course.time
                ) { result in
                    apply(courseResult: result, replacing: course.id.isEmpty ? nil : course)
                }
                .presentationDetents([.large])
            }
            .sheet(item: Binding(
                get: {
                    detailCourseID.flatMap { id in
                        store.activeTerm?.courses.first { $0.id == id }
                    }
                },
                set: { detailCourseID = $0?.id }
            )) { course in
                CourseDetailView(course: course, term: term) { updated in
                    store.updateCourse(updated)
                } onDelete: {
                    store.deleteCourse(id: course.id)
                    detailCourseID = nil
                } onHide: {
                    var copy = course
                    copy.hidden = true
                    store.updateCourse(copy)
                    detailCourseID = nil
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isAddingCourse) {
                QuickAddView { course in
                    store.addCourse(course)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTermPicker) {
                TermPickerView()
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func scheduleContent(term: Term) -> some View {
        VStack(spacing: 0) {
            weekHeader(term: term)
            if viewMode == .week {
                WeekGridView(
                    term: term,
                    profile: store.timingProfile,
                    preferences: preferences,
                    displayWeekStart: displayWeekStart,
                    onTapCourse: { detailCourseID = $0 },
                    onLongPressCourse: { id in
                        if let course = store.activeTerm?.courses.first(where: { $0.id == id }) {
                            editingCourse = course
                        }
                    },
                    onTapEmpty: { _, _ in isAddingCourse = true }
                )
            } else {
                DayView(
                    term: term,
                    profile: store.timingProfile,
                    date: selectedDay,
                    onOpenCourse: { detailCourseID = $0 }
                )
            }
        }
    }

    private var selectedDay: Date {
        let today = Calendar.current.startOfDay(for: .now)
        let weekDates = currentWeekDates()
        if weekDates.contains(today) { return today }
        return weekDates.first ?? today
    }

    private func currentWeekDates() -> [Date] {
        let days = displayDays()
        return (0..<days.count).compactMap { ScheduleCalendar.addDays($0, to: displayWeekStart) }
    }

    private func displayDays() -> [Int] {
        var days: [Int]
        if preferences.showWeekend {
            let start = preferences.weekStart.isoDayOfWeek
            days = (0..<7).map { (($0 + start - 2) % 7) + 1 }
        } else if preferences.showSaturday {
            days = [1, 2, 3, 4, 5, 6]
        } else {
            days = [1, 2, 3, 4, 5]
        }
        return days
    }

    // MARK: - Header

    private var navigationTitle: String {
        term?.name ?? String(localized: "schedule.title")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showTermPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(navigationTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.accentColor)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    viewMode = viewMode == .week ? .day : .week
                }
            } label: {
                Image(systemName: viewMode == .week ? "rectangle.grid.1x2" : "calendar")
            }
            .accessibilityLabel(viewMode == .week ? "schedule.showDay" : "schedule.showWeek")

            Button {
                editingCourse = CourseItem(title: "", time: CourseTimeSlot(dayOfWeek: 1, startNode: 1, endNode: 2))
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("schedule.addCourse")
        }
    }

    private func weekHeader(term: Term) -> some View {
        let days = displayDays()
        let weekNumber = term.weekNumber(on: displayWeekStart, calendar: .current)

        return VStack(spacing: 10) {
            HStack {
                Text(weekHeaderText(weekNumber))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(weekNumber.map { $0 >= 1 } == true ? Color.accentColor : Color.secondary)

                Spacer()

                HStack(spacing: 4) {
                    CircleIconButton(systemImage: "chevron.left", label: "schedule.previousWeek") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayWeekStart = ScheduleCalendar.addWeeks(-1, to: displayWeekStart)
                        }
                    }
                    CircleIconButton(systemImage: "chevron.right", label: "schedule.nextWeek") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            displayWeekStart = ScheduleCalendar.addWeeks(1, to: displayWeekStart)
                        }
                    }
                }
            }
            .padding(.horizontal, AppMetrics.pagePadding)

            if viewMode == .week {
                HStack(spacing: 0) {
                    Text(Format.weekdayNarrow(days[0]))
                        .frame(width: 34)
                    ForEach(days, id: \.self) { day in
                        dayColumnHeader(day: day)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            }
        }
        .padding(.top, 8)
    }

    private func dayColumnHeader(day: Int) -> some View {
        let date = columnDate(for: day)
        let isToday = Calendar.current.isDateInToday(date)

        return VStack(spacing: 2) {
            Text(Format.weekdayNarrow(day))
            Text(date.formatted(.dateTime.day()))
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.white : Color.secondary)
                .frame(width: 20, height: 20)
                .background {
                    if isToday {
                        Circle().fill(Color.accentColor)
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekHeaderText(_ weekNumber: Int?) -> String {
        guard let weekNumber else {
            return String(localized: "week.termStartMissing")
        }
        if weekNumber < 1 {
            return String(localized: "week.notStarted")
        }
        return String(format: String(localized: "week.number"), weekNumber)
    }

    private func columnDate(for day: Int) -> Date {
        let startISO = preferences.weekStart.isoDayOfWeek
        let offset = (day - startISO + 7) % 7
        return ScheduleCalendar.addDays(offset, to: displayWeekStart)
    }

    // MARK: - Editing

    private func apply(courseResult: CourseEditorResult, replacing original: CourseItem?) {
        if var course = courseResult.course {
            if let original {
                course.id = original.id
                store.updateCourse(course)
            } else {
                store.addCourse(course)
            }
        } else if let original, courseResult.deleted {
            store.deleteCourse(id: original.id)
        }
    }
}

enum ScheduleViewMode: String, CaseIterable {
    case week
    case day
}
