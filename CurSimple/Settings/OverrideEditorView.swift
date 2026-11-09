import CurSimpleCore
import SwiftUI

struct OverrideEditorView: View {

    let onCommit: (TemporaryScheduleOverride) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var type: TemporaryScheduleOverrideType = .makeUp
    @State private var sourceDate: Date = .now
    @State private var targetDate: Date = .now
    @State private var courseID: String?
    @State private var partialMakeUp = false
    @State private var makeUpStart = 1
    @State private var makeUpEnd = 2
    @State private var moveStart = 1
    @State private var moveEnd = 2

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(colors: colors)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        typeCard(colors: colors)
                        dateCard(colors: colors)
                        if type != .makeUp {
                            courseCard(colors: colors)
                        }
                        if type == .makeUp {
                            makeUpRangeCard(colors: colors)
                        } else if type == .moveCourse {
                            moveRangeCard(colors: colors)
                        }
                        if !isValid {
                            Text("override.invalid")
                                .font(AppFont.label)
                                .foregroundStyle(colors.error)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear(perform: loadDefaults)
    }

    private func topBar(colors: AppColors) -> some View {
        ZStack {
            Text("override.add")
                .appFont(16, weight: .semibold)
                .foregroundStyle(colors.onBackground)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .appFont(15, weight: .semibold)
                        .foregroundStyle(colors.onBackground)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.cancel")

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
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 8)
    }

    private func typeCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            HStack(spacing: 6) {
                ForEach(TemporaryScheduleOverrideType.allCases) { value in
                    let selected = type == value
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            type = value
                        }
                    } label: {
                        Text(LocalizedStringKey(value.localizationKey))
                            .appFont(12, weight: .semibold)
                            .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                            .frame(maxWidth: .infinity, minHeight: 34)
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

    private func dateCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            if type == .makeUp || type == .moveCourse {
                dateRow("override.sourceDate", selection: $sourceDate, colors: colors)
                Divider().overlay(colors.outlineVariant).padding(.vertical, 2)
            }
            dateRow(dateLabelKey, selection: $targetDate, colors: colors)
        }
    }

    private func courseCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Menu {
                ForEach(activeCourses) { course in
                    Button(course.title) { courseID = course.id }
                }
            } label: {
                HStack {
                    Text("override.course")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Spacer()
                    Text(selectedCourse?.title ?? String(localized: "override.course.none"))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(selectedCourse == nil ? colors.onSurfaceVariant : colors.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .appFont(10, weight: .semibold)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private func makeUpRangeCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Toggle(isOn: $partialMakeUp.animation(.easeOut(duration: 0.16))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("override.partial")
                        .font(AppFont.body)
                        .foregroundStyle(colors.onSurface)
                    Text("override.partial.footer")
                        .font(AppFont.label)
                        .foregroundStyle(colors.onSurfaceVariant)
                }
            }
            .tint(colors.primary)

            if partialMakeUp {
                Divider().overlay(colors.outlineVariant).padding(.vertical, 4)
                nodeRangeRow(
                    start: $makeUpStart,
                    end: $makeUpEnd,
                    colors: colors
                )
            }
        }
    }

    private func moveRangeCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            Text("override.targetPeriods")
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
            nodeRangeRow(start: $moveStart, end: $moveEnd, colors: colors)
        }
    }

    private func nodeRangeRow(
        start: Binding<Int>,
        end: Binding<Int>,
        colors: AppColors
    ) -> some View {
        HStack(spacing: 10) {
            Text("override.nodeRange")
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer()
            nodeMenu(start.wrappedValue, colors: colors) { value in
                start.wrappedValue = value
                if end.wrappedValue < value { end.wrappedValue = value }
            }
            Text("–")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
            nodeMenu(end.wrappedValue, colors: colors) { value in
                end.wrappedValue = value
                if start.wrappedValue > value { start.wrappedValue = value }
            }
        }
        .frame(minHeight: 44)
    }

    private func nodeMenu(_ value: Int, colors: AppColors, onSelect: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(1...maxNode, id: \.self) { node in
                Button(Format.period(node)) { onSelect(node) }
            }
        } label: {
            Text(Format.period(value))
                .appFont(13, weight: .medium)
                .foregroundStyle(colors.primary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(colors.primaryContainer))
        }
        .buttonStyle(.plain)
    }

    private func dateRow(
        _ label: LocalizedStringKey,
        selection: Binding<Date>,
        colors: AppColors
    ) -> some View {
        HStack {
            Text(label)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    // MARK: - Derived

    private var activeCourses: [CourseItem] {
        (store.activeTerm?.courses ?? [])
            .filter { !$0.hidden }
            .sorted { $0.title < $1.title }
    }

    private var selectedCourse: CourseItem? {
        activeCourses.first { $0.id == courseID }
    }

    private var maxNode: Int {
        max(store.timingProfile.slots.map(\.endNode).max() ?? 0, 12)
    }

    private var dateLabelKey: LocalizedStringKey {
        type == .cancelCourse ? "override.date" : "override.targetDate"
    }

    private var isValid: Bool {
        switch type {
        case .makeUp:
            !Calendar.current.isDate(sourceDate, inSameDayAs: targetDate)
        case .cancelCourse:
            selectedCourse != nil
        case .moveCourse:
            selectedCourse != nil && !Calendar.current.isDate(sourceDate, inSameDayAs: targetDate)
        }
    }

    // MARK: - Actions

    private func loadDefaults() {
        if let term = store.activeTerm,
           let start = term.startDateValue {
            sourceDate = start
            targetDate = start
        }
        courseID = activeCourses.first?.id
        if let course = selectedCourse {
            moveStart = course.time.startNode
            moveEnd = course.time.endNode
        }
    }

    private func save() {
        guard isValid else { return }
        let source = DateOnly.string(from: sourceDate)
        let target = DateOnly.string(from: targetDate)

        switch type {
        case .makeUp:
            let override = TemporaryScheduleOverride(
                type: .makeUp,
                targetDate: target,
                sourceDate: source,
                makeUpStartNode: partialMakeUp ? makeUpStart : nil,
                makeUpEndNode: partialMakeUp ? makeUpEnd : nil
            )
            onCommit(override)
        case .cancelCourse:
            guard let course = selectedCourse else { return }
            let override = TemporaryScheduleOverride(
                type: .cancelCourse,
                targetDate: target,
                cancelStartNode: course.time.startNode,
                cancelEndNode: course.time.endNode,
                cancelCourseId: course.id
            )
            onCommit(override)
        case .moveCourse:
            guard let course = selectedCourse else { return }
            let override = TemporaryScheduleOverride(
                type: .moveCourse,
                targetDate: target,
                sourceDate: source,
                moveCourseId: course.id,
                moveToStartNode: moveStart,
                moveToEndNode: moveEnd
            )
            onCommit(override)
        }
        dismiss()
    }
}
