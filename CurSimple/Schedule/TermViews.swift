import CurSimpleCore
import SwiftUI

/// Quick add from tapping an empty grid cell: minimal fields, sensible defaults.
struct QuickAddView: View {

    let onCreate: (CourseItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var title = ""
    @State private var dayOfWeek = 1
    @State private var startNode = 1
    @State private var endNode = 2

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("course.field.title", text: $title)
                }
                Section {
                    Picker("course.field.day", selection: $dayOfWeek) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Format.weekday(day)).tag(day)
                        }
                    }
                    Picker("course.field.periods", selection: Binding(
                        get: { "\(startNode)-\(endNode)" },
                        set: { raw in
                            let parts = raw.split(separator: "-").compactMap { Int($0) }
                            if parts.count == 2 {
                                startNode = parts[0]
                                endNode = parts[1]
                            }
                        }
                    )) {
                        ForEach(periodRanges, id: \.key) { range in
                            Text(range.label).tag(range.key)
                        }
                    }
                }
            }
            .navigationTitle("course.quickAdd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.add") {
                        let course = CourseItem(
                            title: title.trimmingCharacters(in: .whitespaces),
                            time: CourseTimeSlot(dayOfWeek: dayOfWeek, startNode: startNode, endNode: endNode)
                        )
                        onCreate(course)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var periodRanges: [(key: String, label: String)] {
        let maxNode = max(store.timingProfile.slots.map(\.endNode).max() ?? 0, 12)
        var ranges: [(key: String, label: String)] = []
        for start in 1...maxNode {
            for end in start...min(start + 4, maxNode) {
                ranges.append((
                    "\(start)-\(end)",
                    Format.periodRange(start, end)
                ))
            }
        }
        return ranges
    }
}

/// Term switcher in the shared card style.
struct TermPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var newTermName = ""
    @State private var showCreate = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("term.picker")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(colors.onBackground)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("common.cancel")
                        Spacer()
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 8)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.state.terms) { term in
                            termCard(term, colors: colors)
                        }

                        if showCreate {
                            createCard(colors: colors)
                        } else {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showCreate = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 15))
                                    Text("term.create")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                }
                                .foregroundStyle(colors.primary)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(colors.surface)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func termCard(_ term: Term, colors: AppColors) -> some View {
        let selected = term.id == store.state.activeTermID
        let startText = DateOnly.parse(term.startDate)
            .map { $0.formatted(.dateTime.year().month(.abbreviated).day()) } ?? String(localized: "term.notStarted")

        return Button {
            store.selectTerm(id: term.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? colors.primary : colors.outline)

                VStack(alignment: .leading, spacing: 3) {
                    Text(term.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.onSurface)
                        .lineLimit(1)

                    Text("\(startText) · \(String(format: String(localized: "term.courseCount"), term.courses.count))")
                        .font(AppFont.bodySmall)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? colors.primaryContainer : colors.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private func createCard(colors: AppColors) -> some View {
        SettingsCard(colors: colors) {
            TextField("term.newName", text: $newTermName)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)

            Button {
                createTerm()
            } label: {
                Text("term.create")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.onPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Capsule().fill(colors.primary))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .disabled(newTermName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(newTermName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private func createTerm() {
        let name = newTermName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let monday = ScheduleCalendar.startOfDisplayWeek(containing: .now, weekStart: .monday)
        store.addTerm(Term(name: name, startDate: DateOnly.string(from: monday)))
        newTermName = ""
        showCreate = false
        dismiss()
    }
}
