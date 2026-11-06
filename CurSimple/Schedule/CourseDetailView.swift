import CurSimpleCore
import SwiftUI

/// Course details with conflict check and quick actions.
struct CourseDetailView: View {

    let course: CourseItem
    let term: Term?
    let onSave: (CourseItem) -> Void
    let onDelete: () -> Void
    let onHide: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(course.title)
                                .font(.title3.weight(.semibold))
                            if course.category == .exam {
                                Text("course.examTag")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.red))
                            }
                        }
                        Text(summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }

                if !course.teacher.isEmpty || !course.location.isEmpty {
                    Section {
                        if !course.teacher.isEmpty {
                            InfoRow(systemImage: "person", title: "course.field.teacher", value: course.teacher)
                        }
                        if !course.location.isEmpty {
                            InfoRow(systemImage: "mappin.and.ellipse", title: "course.field.location", value: course.location)
                        }
                        if !course.weeks.isEmpty {
                            InfoRow(systemImage: "number", title: "course.field.weeks", value: Format.weekSummary(course.weeks))
                        }
                    }
                }

                ForEach(course.details) { detail in
                    Section {
                        InfoRow(systemImage: "info.circle", title: .init(detail.label), value: detail.value)
                    }
                }

                let conflicts = currentConflicts()
                if !conflicts.isEmpty {
                    Section {
                        ConflictBanner(message: conflictMessage(conflicts))
                    }
                }

                Section {
                    Button {
                        onHide()
                        dismiss()
                    } label: {
                        Label("course.hide", systemImage: "eye.slash")
                    }
                } footer: {
                    Text("course.hide.footer")
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("course.delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("course.detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var summaryLine: String {
        var parts: [String] = []
        parts.append(Format.weekday(course.time.dayOfWeek))
        parts.append(Format.periodRange(course.time.startNode, course.time.endNode))

        if let start = resolvedStart, let end = resolvedEnd {
            parts.append(Format.timeRange(start: start, end: end))
        }

        if let week = term?.weekNumber(on: .now, calendar: .current), week >= 1 {
            let active = course.isActive(inWeek: week)
            parts.append(
                String(
                    format: String(localized: active ? "course.activeThisWeek" : "course.inactiveThisWeek"),
                    week
                )
            )
        }
        return parts.joined(separator: " · ")
    }

    private var resolvedStart: Date? {
        let clock = occurrenceClock(for: course, profile: store.timingProfile)
        return clock?.start.date(on: .now)
    }

    private var resolvedEnd: Date? {
        let clock = occurrenceClock(for: course, profile: store.timingProfile)
        return clock?.end.date(on: .now)
    }

    private func currentConflicts() -> [CourseConflict] {
        guard let term else { return [] }
        let others = term.courses.filter { $0.id != course.id }
        return conflicts(with: course, in: others, maxWeekCount: term.weekCount)
    }

    private func conflictMessage(_ conflicts: [CourseConflict]) -> String {
        let separator = String(localized: "list.separator")
        return conflicts.prefix(3).map { conflict in
            let other = conflict.first.id == course.id ? conflict.second : conflict.first
            return "\(other.title)（\(Format.weekday(conflict.dayOfWeek)) \(Format.periodRange(conflict.overlappingNodes.lowerBound, conflict.overlappingNodes.upperBound))）"
        }.joined(separator: separator)
    }
}
