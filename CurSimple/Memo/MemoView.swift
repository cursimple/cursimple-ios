import CurSimpleCore
import SwiftUI

/// Memo list matching the shared layout: filter pill, three stat cards,
/// checklist-rich cards and a floating add button.
struct MemoView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var filter: MemoFilter = .all
    @State private var searchText = ""
    @State private var courseFilter: String?
    @State private var showSearch = false
    @State private var editingNote: MemoNote? = ProcessInfo.processInfo.arguments.contains("-openMemoEditor")
        ? MemoNote()
        : nil

    enum MemoFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case today
        case overdue
        case done

        var id: String { rawValue }
        var titleKey: LocalizedStringKey {
            switch self {
            case .all: "memo.filter.all"
            case .active: "memo.filter.active"
            case .today: "memo.filter.today"
            case .overdue: "memo.filter.overdue"
            case .done: "memo.filter.done"
            }
        }
    }

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack(alignment: .bottomTrailing) {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("tab.memo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.onBackground)

                    HStack {
                        Button(action: onOpenDrawer) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundStyle(colors.onBackground)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("drawer.open")

                        Spacer()

                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showSearch.toggle()
                                if !showSearch { searchText = "" }
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(colors.onBackground)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("memo.search")
                    }
                }
                .frame(height: 48)
                .padding(.horizontal, 6)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        filterPill(colors: colors)

                        if showSearch || !searchText.isEmpty {
                            searchField(colors: colors)
                        }

                        if !courseKeys.isEmpty {
                            courseFilterRow(colors: colors)
                        }

                        statCards(colors: colors)

                        if visibleNotes.isEmpty {
                            emptyState(colors: colors)
                        } else {
                            ForEach(visibleNotes) { note in
                                MemoCard(note: note, now: Date()) {
                                    editingNote = note
                                } onToggleChecklist: { itemText in
                                    store.toggleMemoChecklist(noteID: note.id, itemText: itemText)
                                } onTogglePin: {
                                    var updated = note
                                    updated.pinned.toggle()
                                    updated.updatedAt = nowMillis()
                                    store.upsertMemo(updated)
                                } onToggleComplete: {
                                    var updated = note
                                    updated.completed.toggle()
                                    updated.updatedAt = nowMillis()
                                    store.upsertMemo(updated)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 92)
                }
            }

            addButton(colors: colors)
                .padding(.trailing, 18)
                .padding(.bottom, 14)
        }
        .sheet(item: $editingNote) { note in
            MemoEditorView(existing: note) { result in
                switch result {
                case .saved(let saved):
                    var updated = saved
                    if updated.createdAt == 0 {
                        updated.createdAt = nowMillis()
                    }
                    updated.updatedAt = nowMillis()
                    store.upsertMemo(updated)
                case .deleted:
                    store.deleteMemo(id: note.id)
                }
            }
            .presentationDetents([.large])
        }
    }

    private func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    // MARK: - Derived

    private var visibleNotes: [MemoNote] {
        let now = Date()
        let all = filtered(store.sortedMemos(now: now))
        switch filter {
        case .all:
            return all
        case .active:
            return all.filter { !$0.completed }
        case .today:
            return all.filter { $0.dueState(at: now) == .today }
        case .overdue:
            return all.filter { $0.dueState(at: now) == .overdue }
        case .done:
            return all.filter(\.completed)
        }
    }

    private func filtered(_ notes: [MemoNote]) -> [MemoNote] {
        var result = notes
        if let courseFilter {
            result = result.filter { $0.courseKey == courseFilter }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(query)
                    || $0.body.lowercased().contains(query)
                    || $0.courseTitle.lowercased().contains(query)
            }
        }
        return result
    }

    private var courseKeys: [(key: String, title: String)] {
        var seen = Set<String>()
        return store.state.memos.compactMap { note in
            guard let key = note.courseKey, !key.isEmpty, seen.insert(key).inserted else { return nil }
            return (key, note.courseTitle.isEmpty ? key : note.courseTitle)
        }
        .sorted { $0.title < $1.title }
    }

    private func count(_ filter: MemoFilter) -> Int {
        let now = Date()
        let notes = filtered(store.state.memos)
        switch filter {
        case .all: return notes.count
        case .active: return notes.filter { !$0.completed }.count
        case .today: return notes.filter { $0.dueState(at: now) == .today }.count
        case .overdue: return notes.filter { $0.dueState(at: now) == .overdue }.count
        case .done: return notes.filter(\.completed).count
        }
    }

    // MARK: - Chrome

    private func filterPill(colors: AppColors) -> some View {
        Menu {
            ForEach(MemoFilter.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        filter = item
                    }
                } label: {
                    if filter == item {
                        Label {
                            Text(item.titleKey)
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text(item.titleKey)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(colors.primary)

                Text(filter.titleKey)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.onSurface)

                Spacer()

                Text("\(count(filter))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.onPrimary)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(colors.primary))

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colors.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private func searchField(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(colors.onSurfaceVariant)
            TextField("memo.search", text: $searchText)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(colors.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func courseFilterRow(colors: AppColors) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseChip(nil, title: String(localized: "memo.course.all"), colors: colors)
                ForEach(courseKeys, id: \.key) { item in
                    courseChip(item.key, title: item.title, colors: colors)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func courseChip(_ key: String?, title: String, colors: AppColors) -> some View {
        let selected = courseFilter == key
        return Button {
            withAnimation(.easeOut(duration: 0.16)) {
                courseFilter = selected ? nil : key
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? colors.onPrimary : colors.onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(selected ? colors.primary : colors.surface))
                .overlay(Capsule().stroke(selected ? Color.clear : colors.outlineVariant, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func statCards(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            statCard("memo.stats.todo", count: count(.active), color: colors.primary, filter: .active, colors: colors)
            statCard("memo.stats.today", count: count(.today), color: Color(red: 0.89, green: 0.60, blue: 0.18), filter: .today, colors: colors)
            statCard("memo.stats.overdue", count: count(.overdue), color: colors.error, filter: .overdue, colors: colors)
        }
    }

    private func statCard(
        _ title: LocalizedStringKey,
        count: Int,
        color: Color,
        filter target: MemoFilter,
        colors: AppColors
    ) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                filter = target
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colors.surface)
            )
            .overlay {
                if filter == target {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(color.opacity(0.45), lineWidth: 1.4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func addButton(colors: AppColors) -> some View {
        Button {
            editingNote = MemoNote()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("memo.addShort")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(colors.onPrimaryContainer)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(
                Capsule().fill(colors.primaryContainer)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("memo.add")
    }

    private func emptyState(colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 24))
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))

            Text("memo.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(colors.onSurface)
            Text("memo.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Card

struct MemoCard: View {

    let note: MemoNote
    let now: Date
    let action: () -> Void
    let onToggleChecklist: (String) -> Void
    let onTogglePin: () -> Void
    let onToggleComplete: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let checklist = note.checklist
        let due = note.dueState(at: now)

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colors.surface)

            if note.priority != .none {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priorityColor(note.priority, colors: colors))
                    .frame(width: 4)
                    .padding(.vertical, 12)
            }

            HStack(alignment: .top, spacing: 10) {
                Button {
                    onToggleComplete()
                } label: {
                    Image(systemName: note.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(note.completed ? colors.primary : colors.outline)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .accessibilityLabel("memo.toggleComplete")

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        if note.pinned && !note.completed {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(colors.onSurfaceVariant)
                        }
                        Text(note.displayTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(note.completed ? colors.onSurfaceVariant : colors.onSurface)
                            .strikethrough(note.completed, color: colors.onSurfaceVariant)
                            .lineLimit(2)

                        Spacer(minLength: 0)

                        Menu {
                            Button(note.pinned ? "memo.unpin" : "memo.pin") { onTogglePin() }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(colors.onSurfaceVariant)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                    }

                    if !note.courseTitle.isEmpty || note.priority != .none || dueChipText(due) != nil {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                if !note.courseTitle.isEmpty {
                                    Text(note.courseTitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(widgetBlueText)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(widgetBlueFill))
                                }
                                if note.priority != .none {
                                    Text(LocalizedStringKey(note.priority.localizationKey))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(priorityColor(note.priority, colors: colors))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(priorityColor(note.priority, colors: colors).opacity(0.14)))
                                }
                                Spacer(minLength: 0)
                            }

                            if let dueText = dueChipText(due) {
                                HStack(spacing: 5) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(dueText)
                                        .font(.system(size: 11, weight: due == .overdue ? .semibold : .regular))
                                }
                                .foregroundStyle(due == .overdue ? colors.error : colors.onSurfaceVariant)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(colors.surfaceVariant.opacity(0.7)))
                            }
                        }
                    }

                    if !plainPreview.isEmpty {
                        Text(plainPreview)
                            .font(.system(size: 14))
                            .foregroundStyle(colors.onSurface)
                            .lineLimit(2)
                    }

                    if checklist.hasItems {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(checklistLines.enumerated()), id: \.offset) { _, item in
                                Button {
                                    onToggleChecklist(item.text)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: item.checked ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 17))
                                            .foregroundStyle(item.checked ? colors.primary : colors.outline)
                                        Text(item.text)
                                            .font(.system(size: 14))
                                            .foregroundStyle(item.checked ? colors.onSurfaceVariant : colors.onSurface)
                                            .strikethrough(item.checked, color: colors.onSurfaceVariant)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 3)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            HStack(spacing: 8) {
                                GeometryReader { proxy in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(colors.surfaceVariant)
                                        Capsule()
                                            .fill(colors.primary)
                                            .frame(width: max(proxy.size.width * checklist.fraction, 4))
                                    }
                                }
                                .frame(height: 5)

                                Text(String(
                                    format: String(localized: "memo.checklistProgress"),
                                    checklist.done,
                                    checklist.total
                                ))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(colors.onSurfaceVariant)
                                .monospacedDigit()
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(14)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: action)
    }

    private var checklistLines: [(checked: Bool, text: String)] {
        note.body.components(separatedBy: "\n").compactMap { MemoChecklist.parseLine($0) }.prefix(5).map { $0 }
    }

    private var plainPreview: String {
        let lines = note.body
            .components(separatedBy: "\n")
            .filter { MemoChecklist.parseLine($0) == nil && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.prefix(2).joined(separator: "\n")
    }

    private func dueChipText(_ state: MemoDueState) -> String? {
        guard let due = note.dueDateTime() else { return nil }
        if note.completed { return nil }
        let clock = TimeOfDay(date: due).text
        let day = due.formatted(.dateTime.month().day())
        switch state {
        case .overdue:
            return String(
                format: String(localized: "memo.due.overdueRelative"),
                relativeText(from: due),
                "\(day) \(clock)"
            )
        case .today:
            return String(format: String(localized: "memo.due.todayAt"), clock)
        case .soon:
            return String(format: String(localized: "memo.due.soonAt"), "\(day) \(clock)")
        case .later:
            return "\(day) \(clock)"
        case .none:
            return nil
        }
    }

    private func relativeText(from due: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(due))
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return String(format: String(localized: "memo.relative.minutes"), max(minutes, 1))
        }
        let hours = minutes / 60
        if hours < 24 {
            return String(format: String(localized: "memo.relative.hours"), hours)
        }
        return String(format: String(localized: "memo.relative.days"), hours / 24)
    }

    private func priorityColor(_ priority: MemoPriority, colors: AppColors) -> Color {
        switch priority {
        case .high: colors.error
        case .medium: Color(red: 0.89, green: 0.60, blue: 0.18)
        case .low: colors.primary
        case .none: .clear
        }
    }

    private var widgetBlueFill: Color {
        Color(.sRGB, red: 0.867, green: 0.922, blue: 0.980, opacity: 1)
    }

    private var widgetBlueText: Color {
        Color(.sRGB, red: 0.173, green: 0.333, blue: 0.529, opacity: 1)
    }
}
