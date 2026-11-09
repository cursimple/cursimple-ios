import CurSimpleCore
import SwiftUI
import WebKit

/// Hosts a plugin's web session, shows its state and imports the submitted draft.
struct PluginRunnerView: View {

    let manifest: PluginManifest
    let script: String
    let onImport: ([CourseItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStore.self) private var store

    @State private var runner: PluginWebRunner?
    @State private var showLog = false

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()
            content(colors: colors)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if runner == nil {
                let created = PluginWebRunner(manifest: manifest, script: script)
                runner = created
                created.start()
            }
        }
        .onDisappear {
            runner?.stop()
        }
        .sheet(isPresented: $showLog) {
            logSheet(colors: colors)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func content(colors: AppColors) -> some View {
        VStack(spacing: 0) {
            header(colors: colors)
            statusBar(colors: colors)
            webArea
            footer(colors: colors)
        }
    }

    @ViewBuilder
    private var webArea: some View {
        if let runner {
            PluginWebView(webView: runner.webViewForDisplay)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
        } else {
            Spacer()
        }
    }

    private func header(colors: AppColors) -> some View {
        ZStack {
            Text(manifest.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colors.onBackground)
                .lineLimit(1)

            HStack {
                Button("common.cancel") { dismiss() }
                    .font(.system(size: 14))
                    .foregroundStyle(colors.primary)

                Spacer()

                Button {
                    showLog = true
                } label: {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 15))
                        .foregroundStyle(colors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("plugin.log")
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }

    private func statusBar(colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(colors: colors))
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(2)

            Spacer()

            if case .loading = runner?.state {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func footer(colors: AppColors) -> some View {
        VStack(spacing: 8) {
            if case .finished(let count) = runner?.state {
                Button {
                    if let courses = runner?.lastDraft {
                        onImport(courses)
                        dismiss()
                    }
                } label: {
                    Text(String(format: String(localized: "plugin.import"), count))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(colors.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    runner?.reload()
                } label: {
                    Label("plugin.reload", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(colors.primary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .overlay(Capsule().stroke(colors.primary.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func logSheet(colors: AppColors) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("plugin.log")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colors.onBackground)
                    .frame(height: 52)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array((runner?.log ?? []).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var statusText: String {
        switch runner?.state ?? .idle {
        case .idle: String(localized: "plugin.state.idle")
        case .loading: String(localized: "plugin.state.loading")
        case .needsLogin: String(localized: "plugin.state.needsLogin")
        case .syncing: String(localized: "plugin.state.syncing")
        case .finished(let count): String(format: String(localized: "plugin.state.finished"), count)
        case .failed(let message): String(format: String(localized: "plugin.state.failed"), message)
        }
    }

    private func statusColor(colors: AppColors) -> Color {
        switch runner?.state ?? .idle {
        case .failed: colors.error
        case .finished: colors.primary
        default: colors.onSurfaceVariant
        }
    }
}

/// UIKit wrapper so the runner owns the `WKWebView` instance.
private struct PluginWebView: UIViewRepresentable {

    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
