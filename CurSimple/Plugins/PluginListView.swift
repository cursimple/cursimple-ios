import CurSimpleCore
import SwiftUI
import UniformTypeIdentifiers

/// School plugin market: install a bundle, list installed plugins and run one.
struct PluginListView: View {

    let onOpenDrawer: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var pluginStore = PluginStore()
    @State private var showImporter = false
    @State private var running: PluginStore.InstalledPlugin?
    @State private var errorMessage: String?
    @State private var installedNotice: String?

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()
            mainContent(colors)
        }
        .modifier(PluginPickerModifier(
            isPresented: $showImporter,
            onPick: { url in installBundle(at: url) }
        ))
        .fullScreenCover(item: $running) { plugin in
            PluginRunnerView(manifest: plugin.manifest, script: plugin.entryScript) { courses in
                importCourses(courses)
            }
            .environment(store)
        }
        .alert("plugin.errorTitle", isPresented: errorAlertBinding) {
            Button("common.done", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            noticeBadge(colors)
        }
    }

    // MARK: - Layout

    private func mainContent(_ colors: AppColors) -> some View {
        VStack(spacing: 0) {
            titleBar(colors)
            scrollContent(colors)
        }
    }

    private func titleBar(_ colors: AppColors) -> some View {
        ZStack {
            Text("plugin.pageTitle")
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
    }

    private func scrollContent(_ colors: AppColors) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                installCard(colors)
                pluginList(colors)
                infoCard(colors)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func pluginList(_ colors: AppColors) -> some View {
        if pluginStore.plugins.isEmpty {
            emptyState(colors)
        } else {
            ForEach(pluginStore.plugins) { plugin in
                pluginRow(plugin, colors)
            }
        }
    }

    @ViewBuilder
    private func noticeBadge(_ colors: AppColors) -> some View {
        if let text = installedNotice {
            Text(text)
                .appFont(13, weight: .medium)
                .foregroundStyle(colors.onPrimary)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule().fill(colors.primary))
                .padding(.bottom, 20)
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    installedNotice = nil
                }
        }
    }

    // MARK: - Cards

    private func installCard(_ colors: AppColors) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .appFont(17, weight: .medium)
                .foregroundStyle(colors.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(colors.primaryContainer))

            VStack(alignment: .leading, spacing: 2) {
                Text("plugin.install")
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(colors.onSurface)
                Text("plugin.install.footer")
                    .font(AppFont.label)
                    .foregroundStyle(colors.onSurfaceVariant)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                showImporter = true
            } label: {
                Text("plugin.install.action")
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(colors.onPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(colors.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func pluginRow(_ plugin: PluginStore.InstalledPlugin, _ colors: AppColors) -> some View {
        HStack(spacing: 10) {
            pluginText(plugin, colors)
            Spacer(minLength: 6)
            runButton(plugin, colors)
            deleteButton(plugin, colors)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.surface)
        )
    }

    private func pluginText(_ plugin: PluginStore.InstalledPlugin, _ colors: AppColors) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(plugin.manifest.name)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(colors.onSurface)
                    .lineLimit(1)
                Text("v" + plugin.manifest.version)
                    .appFont(10, weight: .medium)
                    .foregroundStyle(colors.onSurfaceVariant)
            }

            Text(plugin.manifest.description.isEmpty ? plugin.manifest.id : plugin.manifest.description)
                .font(AppFont.label)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(2)
        }
    }

    private func runButton(_ plugin: PluginStore.InstalledPlugin, _ colors: AppColors) -> some View {
        Button {
            running = plugin
        } label: {
            Text("plugin.run")
                .appFont(12, weight: .semibold)
                .foregroundStyle(colors.onPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(colors.primary))
        }
        .buttonStyle(.plain)
    }

    private func deleteButton(_ plugin: PluginStore.InstalledPlugin, _ colors: AppColors) -> some View {
        Button {
            pluginStore.uninstall(id: plugin.id)
        } label: {
            Image(systemName: "trash")
                .appFont(14)
                .foregroundStyle(colors.error)
                .frame(width: 32, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("plugin.uninstall")
    }

    private func emptyState(_ colors: AppColors) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .appFont(24)
                .foregroundStyle(colors.primary)
                .frame(width: 52, height: 52)
                .background(Circle().fill(colors.primaryContainer))
            Text("plugin.empty.title")
                .appFont(14, weight: .semibold)
                .foregroundStyle(colors.onSurface)
            Text("plugin.empty.message")
                .font(AppFont.bodySmall)
                .foregroundStyle(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func infoCard(_ colors: AppColors) -> some View {
        Text("plugin.info")
            .font(AppFont.label)
            .foregroundStyle(colors.onSurfaceVariant)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colors.surface)
            )
    }

    // MARK: - Actions

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func installBundle(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
            if let installed = pluginStore.install(archive: data, hostVersion: version) {
                installedNotice = String(
                    format: String(localized: "plugin.installed"),
                    installed.manifest.name
                )
            } else {
                errorMessage = pluginStore.lastError ?? String(localized: "plugin.error.install")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importCourses(_ courses: [CourseItem]) {
        guard var term = store.activeTerm else { return }
        term.courses.removeAll { $0.id.hasPrefix("plugin-") }
        term.courses.append(contentsOf: courses)
        store.updateTerm(term)
    }
}

/// Wraps the document picker so the view body stays small for the type checker.
private struct PluginPickerModifier: ViewModifier {

    @Binding var isPresented: Bool
    let onPick: (URL) -> Void

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [.zip, .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                onPick(url)
            }
        }
    }
}
