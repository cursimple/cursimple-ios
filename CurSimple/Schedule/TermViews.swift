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

/// Switch between terms or create a new one.
struct TermPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var newTermName = ""
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.state.terms) { term in
                    Button {
                        store.selectTerm(id: term.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(term.name)
                                    .foregroundStyle(.primary)
                                Text(termSubtitle(term))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if term.id == store.state.activeTermID {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                if showCreate {
                    Section {
                        TextField("term.newName", text: $newTermName)
                        Button("term.create") {
                            createTerm()
                        }
                        .disabled(newTermName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCreate = true
                        }
                    } label: {
                        Label("term.create", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("term.picker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func termSubtitle(_ term: Term) -> String {
        var parts: [String] = []
        if let start = DateOnly.parse(term.startDate) {
            parts.append(DateOnly.string(from: start))
        }
        parts.append(String(format: String(localized: "term.weekCount"), term.weekCount))
        parts.append(String(format: String(localized: "term.courseCount"), term.courses.count))
        return parts.joined(separator: " · ")
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
