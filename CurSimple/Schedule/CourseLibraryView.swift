import CurSimpleCore
import SwiftUI

/// Course and event list matching the shared "管理列表" layout: search field,
/// two add buttons, a course/event segmented control and rows with edit and
/// delete actions.
struct CourseLibraryView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var search = ""
    @State private var tab: LibraryTab = .courses
    @State private var editorTarget: CourseEditorTarget?

    private enum LibraryTab: String, CaseIterable, Identifiable {
        case courses
        case exams
        case events

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .courses: "library.courses"
            case .exams: "library.exams"
            case .events: "library.events"
            }
        }

        var category: CourseCategory {
            switch self {
            case .courses: .course
            case .exams: .exam
            case .events: .event
            }
        }
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("library.title")
                        .appFont(16, weight: .semibold)
                        .foregroundStyle(colors.onBackground)

                    HStack {
                        Button(action: onOpenDrawer) {
                            Image(systemName: "line.3.horizontal")
                                .appFont(21, weight: .medium)
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
                    VStack(alignment: .leading, spacing: 12) {
                        searchField(colors: colors)
                        addButtons(colors: colors)
                        segmented(colors: colors)
                        rows(colors: colors)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            CourseEditorView(editing: target.course, initialSlot: target.slot) { result in
                commit(result, target: target)
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Chrome

    private func searchField(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .appFont(14)
                .foregroundStyle(colors.onSurfaceVariant)

            TextField("library.search", text: $search)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .appFont(14)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(colors.outlineVariant, lineWidth: 1)
        )
    }

    private func addButtons(colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Button {
                editorTarget = CourseEditorTarget(
                    course: nil,
                    slot: CourseTimeSlot(dayOfWeek: 1, startNode: 1, endNode: 2)
                )
            } label: {
                Text("library.addCourse")
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(colors.primary))
            }
            .buttonStyle(.plain)

            Button {
                tab = .events
                editorTarget = CourseEditorTarget(
                    course: nil,
                    slot: CourseTimeSlot(dayOfWeek: 1, startNode: 5, endNode: 6),
                    presetCategory: .event
                )
            } label: {
                Text("library.addEvent")
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(colors.onSurface)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Capsule().fill(colors.primaryContainer.opacity(0.55)))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func segmented(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            ForEach(LibraryTab.allCases) { item in
                segmentButton(
                    item.titleKey,
                    count: count(of: item),
                    selected: tab == item,
                    colors: colors
                ) {
                    tab = item
                }
            }
            Spacer()
        }
    }

    private func segmentButton(
        _ title: LocalizedStringKey,
        count: Int,
        selected: Bool,
        colors: AppColors,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text("\(Text(title)) \(count)")
                .appFont(13, weight: .medium)
                .foregroundStyle(selected ? colors.primary : colors.onSurfaceVariant)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(selected ? colors.primaryContainer : colors.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(selected ? colors.primary.opacity(0.45) : colors.outlineVariant, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func rows(colors: AppColors) -> some View {
        let list = items(of: tab)
        return VStack(spacing: 8) {
            if list.isEmpty {
                Text(emptyKey(for: tab))
                    .font(AppFont.bodySmall)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(list) { course in
                    row(course, colors: colors)
                }
            }
        }
    }

    private func row(_ course: CourseItem, colors: AppColors) -> some View {
        let entry = CoursePalette.courseEntry(
            for: course,
            style: store.preferences.paletteStyle,
            dark: colorScheme == .dark
        )

        return HStack(spacing: 10) {
            Circle()
                .fill(entry.container.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(course.title)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(colors.onSurface)
                    .lineLimit(1)

                Text(detailLine(course))
                    .appFont(12)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(1)

                if !course.location.isEmpty {
                    Text(course.location)
                        .appFont(12)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Button {
                editorTarget = CourseEditorTarget(course: course, slot: course.time)
            } label: {
                Image(systemName: "pencil")
                    .appFont(15, weight: .medium)
                    .foregroundStyle(colors.onSurface)
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("library.edit")

            Button {
                store.deleteCourse(id: course.id)
            } label: {
                Image(systemName: "trash")
                    .appFont(15, weight: .medium)
                    .foregroundStyle(colors.onSurface)
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("library.delete")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surface)
        )
    }

    // MARK: - Data

    private var allCourses: [CourseItem] {
        (store.activeTerm?.courses ?? []).filter { !$0.hidden }
    }

    private func items(of tab: LibraryTab) -> [CourseItem] {
        filtered(allCourses.filter { $0.category == tab.category })
    }

    private func count(of tab: LibraryTab) -> Int {
        allCourses.filter { $0.category == tab.category }.count
    }

    private func emptyKey(for tab: LibraryTab) -> LocalizedStringKey {
        switch tab {
        case .courses: "library.courses.empty"
        case .exams: "library.exams.empty"
        case .events: "library.events.empty"
        }
    }

    private func filtered(_ list: [CourseItem]) -> [CourseItem] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let matched = query.isEmpty ? list : list.filter {
            $0.title.lowercased().contains(query)
                || $0.teacher.lowercased().contains(query)
                || $0.location.lowercased().contains(query)
        }
        return matched.sorted {
            ($0.time.dayOfWeek, $0.time.startNode, $0.title)
                < ($1.time.dayOfWeek, $1.time.startNode, $1.title)
        }
    }

    private func detailLine(_ course: CourseItem) -> String {
        var parts = [
            Format.weekday(course.time.dayOfWeek),
            Format.periodRange(course.time.startNode, course.time.endNode),
        ]
        let clock = occurrenceClock(for: course, profile: store.timingProfile)
        if let clock {
            parts.append("\(clock.start.text)-\(clock.end.text)")
        }
        return parts.joined(separator: " ")
    }

    private func commit(_ result: CourseEditorResult, target: CourseEditorTarget) {
        if let course = result.course {
            if let original = target.course {
                var updated = course
                updated.id = original.id
                store.updateCourse(updated)
            } else {
                store.addCourse(course)
            }
        } else if result.deleted, let original = target.course {
            store.deleteCourse(id: original.id)
        }
    }
}
