import CurSimpleCore
import SwiftUI

/// Pick a school from the bundled catalog, then sign in to its portal and let
/// the generic extractor read the timetable.
struct SchoolImportView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var query = ""
    @State private var selected: SchoolPortalEntry?
    @State private var schools: [SchoolPortalEntry] = []

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)
        let results = SchoolPortalCatalog.search(schools, query: query)

        ZStack {
            colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar(colors)
                searchField(colors)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        if results.isEmpty {
                            emptyState(colors)
                        } else {
                            ForEach(results.prefix(200)) { school in
                                schoolRow(school, colors)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            if schools.isEmpty {
                schools = SchoolPortalCatalog.loadBundled()
            }
        }
        .fullScreenCover(item: $selected) { school in
            SchoolPortalRunnerView(school: school) { courses in
                importCourses(courses)
            }
            .environment(store)
        }
    }

    private func titleBar(_ colors: AppColors) -> some View {
        ZStack {
            Text("school.pageTitle")
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
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 6)
    }

    private func searchField(_ colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(colors.onSurfaceVariant)
            TextField("school.search", text: $query)
                .font(AppFont.body)
                .foregroundStyle(colors.onSurface)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
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
        .padding(.horizontal, 14)
    }

    private func schoolRow(_ school: SchoolPortalEntry, _ colors: AppColors) -> some View {
        Button {
            selected = school
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 14))
                    .foregroundStyle(colors.primary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(colors.primaryContainer))

                VStack(alignment: .leading, spacing: 1) {
                    Text(school.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(colors.onSurface)
                        .lineLimit(1)
                    if let host = school.host {
                        Text(host)
                            .font(.system(size: 10))
                            .foregroundStyle(colors.onSurfaceVariant)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.onSurfaceVariant)
            }
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colors.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ colors: AppColors) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(colors.primary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(colors.primaryContainer))
            Text("school.empty")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func importCourses(_ courses: [CourseItem]) {
        guard var term = store.activeTerm else { return }
        term.courses.removeAll { $0.id.hasPrefix("plugin-") }
        term.courses.append(contentsOf: courses)
        store.updateTerm(term)
    }
}
