import CurSimpleCore
import SwiftUI

struct OverrideSettingsView: View {

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isAdding = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let overrides = store.state.overrides.sorted { $0.targetDate > $1.targetDate }

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    SettingsHeader(title: "override.pageTitle", colors: colors, onBack: { dismiss() })

                    HStack {
                        Spacer()
                        Button {
                            isAdding = true
                        } label: {
                            Image(systemName: "plus")
                                .appFont(16, weight: .medium)
                                .foregroundStyle(colors.primary)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .accessibilityLabel("override.add")
                    }
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if overrides.isEmpty {
                            SettingsCard(colors: colors) {
                                Text("override.empty")
                                    .font(AppFont.bodySmall)
                                    .foregroundStyle(colors.onSurfaceVariant)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        } else {
                            SettingsCard(colors: colors) {
                                ForEach(Array(overrides.enumerated()), id: \.element.id) { index, override in
                                    overrideRow(override, colors: colors)
                                    if index < overrides.count - 1 {
                                        Divider().overlay(colors.outlineVariant).padding(.vertical, 2)
                                    }
                                }
                            }
                        }

                        SettingsCard(colors: colors) {
                            Text("override.footer")
                                .font(AppFont.label)
                                .foregroundStyle(colors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isAdding) {
            OverrideEditorView(onCommit: { override in
                store.upsertOverride(override)
            })
            .presentationDetents([.large])
        }
    }

    private func overrideRow(_ override: TemporaryScheduleOverride, colors: AppColors) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: override.type))
                .appFont(13)
                .foregroundStyle(colors.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(typeLabel(override.type))
                        .appFont(10, weight: .semibold)
                        .foregroundStyle(colors.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(colors.primaryContainer))

                    Text(courseTitle(for: override))
                        .appFont(13, weight: .medium)
                        .foregroundStyle(colors.onSurface)
                        .lineLimit(1)
                }

                Text(summary(override))
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button {
                store.deleteOverride(id: override.id)
            } label: {
                Image(systemName: "trash")
                    .appFont(13)
                    .foregroundStyle(colors.error)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("holiday.delete")
        }
        .frame(minHeight: 48)
    }

    private func icon(for type: TemporaryScheduleOverrideType) -> String {
        switch type {
        case .makeUp: "arrow.triangle.swap"
        case .cancelCourse: "xmark.circle"
        case .moveCourse: "arrow.right.circle"
        }
    }

    private func typeLabel(_ type: TemporaryScheduleOverrideType) -> String {
        switch type {
        case .makeUp: String(localized: "override.type.makeUp")
        case .cancelCourse: String(localized: "override.type.cancelCourse")
        case .moveCourse: String(localized: "override.type.moveCourse")
        }
    }

    private func courseTitle(for override: TemporaryScheduleOverride) -> String {
        guard let id = override.cancelCourseId ?? override.moveCourseId,
              let course = store.activeTerm?.courses.first(where: { $0.id == id }) else {
            return ""
        }
        return course.title
    }

    private func summary(_ override: TemporaryScheduleOverride) -> String {
        switch override.type {
        case .makeUp:
            let range = override.makeUpNodeRange.map {
                Format.periodRange($0.lowerBound, $0.upperBound)
            }
            let base = "\(override.sourceDate) → \(override.targetDate)"
            return range.map { "\(base) · \($0)" } ?? base
        case .cancelCourse:
            let range = if let start = override.cancelStartNode {
                Format.periodRange(start, override.cancelEndNode ?? start)
            } else {
                ""
            }
            return range.isEmpty ? override.targetDate : "\(override.targetDate) · \(range)"
        case .moveCourse:
            let range = override.moveToNodeRange.map {
                Format.periodRange($0.lowerBound, $0.upperBound)
            }
            let base = "\(override.sourceDate) → \(override.targetDate)"
            return range.map { "\(base) · \($0)" } ?? base
        }
    }
}
