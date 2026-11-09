import CurSimpleCore
import SwiftUI
import WebKit

/// Opens a school portal, lets the user sign in, then runs the bundled generic
/// timetable extractor inside the page.
struct SchoolPortalRunnerView: View {

    let school: SchoolPortalEntry
    let onImport: ([CourseItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStore.self) private var store

    @State private var controller: SchoolPortalController?

    var body: some View {
        let colors = AppColors.resolve(accent: store.preferences.accent, dark: colorScheme == .dark)

        ZStack {
            colors.background.ignoresSafeArea()
            content(colors)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: start)
        .onDisappear { controller?.stop() }
    }

    private func start() {
        guard controller == nil else { return }
        let created = SchoolPortalController(school: school)
        controller = created
        created.start()
    }

    @ViewBuilder
    private func content(_ colors: AppColors) -> some View {
        VStack(spacing: 0) {
            header(colors)
            statusRow(colors)
            webArea
            actions(colors)
        }
    }

    private func header(_ colors: AppColors) -> some View {
        ZStack {
            Text(school.name)
                .appFont(15, weight: .semibold)
                .foregroundStyle(colors.onBackground)
                .lineLimit(1)
                .padding(.horizontal, 60)

            HStack {
                Button("common.cancel") { dismiss() }
                    .appFont(14)
                    .foregroundStyle(colors.primary)
                Spacer()
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }

    private func statusRow(_ colors: AppColors) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(colors))
                .frame(width: 8, height: 8)
            Text(statusText)
                .appFont(12)
                .foregroundStyle(colors.onSurfaceVariant)
                .lineLimit(2)
            Spacer()
            if controller?.isBusy == true {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var webArea: some View {
        if let controller {
            SchoolWebView(webView: controller.webView)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 12)
        } else {
            Spacer()
        }
    }

    private func actions(_ colors: AppColors) -> some View {
        VStack(spacing: 8) {
            if let courses = controller?.courses, !courses.isEmpty {
                Button {
                    onImport(courses)
                    dismiss()
                } label: {
                    Text(String(format: String(localized: "plugin.import"), courses.count))
                        .appFont(15, weight: .semibold)
                        .foregroundStyle(colors.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(colors.primary))
                }
                .buttonStyle(.plain)
            }

            Button {
                controller?.extractTimetable()
            } label: {
                Label("school.extract", systemImage: "tablecells")
                    .appFont(14, weight: .medium)
                    .foregroundStyle(colors.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(Capsule().stroke(colors.primary.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(controller?.isBusy == true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusText: String {
        switch controller?.status ?? .idle {
        case .idle: String(localized: "school.status.idle")
        case .loading: String(localized: "school.status.loading")
        case .ready: String(localized: "school.status.ready")
        case .extracting: String(localized: "school.status.extracting")
        case .found(let count): String(format: String(localized: "school.status.found"), count)
        case .failed(let message): String(format: String(localized: "school.status.failed"), message)
        }
    }

    private func statusColor(_ colors: AppColors) -> Color {
        switch controller?.status ?? .idle {
        case .failed: colors.error
        case .found: colors.primary
        default: colors.onSurfaceVariant
        }
    }
}

/// Owns the portal web view, host allowlisting and the extractor injection.
@MainActor
@Observable
final class SchoolPortalController: NSObject {

    enum Status: Equatable {
        case idle
        case loading
        case ready
        case extracting
        case found(Int)
        case failed(String)
    }

    let school: SchoolPortalEntry
    let webView: WKWebView
    private(set) var status: Status = .idle
    private(set) var courses: [CourseItem] = []
    private(set) var isBusy = false

    private let handler: MessageBridge = MessageBridge()
    private var extractor: String = ""

    init(school: SchoolPortalEntry) {
        self.school = school
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = handler.controller
        configuration.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        handler.onMessage = { [weak self] message in
            self?.handle(message)
        }
        webView.navigationDelegate = self
        handler.controller.add(self, name: "cursimple")
        installBridge()
        extractor = Self.loadExtractor()
    }

    func start() {
        guard let raw = school.portalUrl, let url = URL(string: raw) else {
            status = .failed(String(localized: "school.error.noPortal"))
            return
        }
        status = .loading
        webView.load(URLRequest(url: url))
    }

    func stop() {
        webView.stopLoading()
    }

    /// Inject the bundled extractor and run it in the signed-in page.
    func extractTimetable() {
        guard !extractor.isEmpty else {
            status = .failed(String(localized: "school.error.noExtractor"))
            return
        }
        status = .extracting
        isBusy = true
        let js = "window.__csExtract = async function(source) { \(Self.runnerPrelude) try { return await (new Function('ctx', 'return (async () => {' + source + '})()'))(window.ctx); } catch (e) { return { hold: true, error: String(e) }; } }; window.__csExtract(\(Self.jsLiteral(extractor)));"
        webView.evaluateJavaScript(js) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                self.isBusy = false
                if let error {
                    self.status = .failed(error.localizedDescription)
                    return
                }
                self.handleExtractorResult(result)
            }
        }
    }

    // MARK: - Bridge

    private func installBridge() {
        let bridge = """
        (function() {
          if (window.__csBridgeInstalled) { return; }
          window.__csBridgeInstalled = true;
          function call(name, payload) {
            return new Promise(function(resolve, reject) {
              var id = 'r' + Math.random().toString(36).slice(2);
              window.__csPending = window.__csPending || {};
              window.__csPending[id] = { resolve: resolve, reject: reject };
              window.webkit.messageHandlers.cursimple.postMessage({
                id: id, name: name, payload: payload === undefined ? null : payload
              });
            });
          }
          window.__csResolve = function(id, ok, value) {
            var pending = (window.__csPending || {})[id];
            if (!pending) { return; }
            delete window.__csPending[id];
            if (ok) { pending.resolve(value); } else { pending.reject(new Error(String(value))); }
          };
          var draft = [];
          window.ctx = {
            term: null,
            log: function(text) { call('log', { text: String(text) }); },
            schedule: {
              addCourse: function(course) { draft.push(course || {}); return draft.length; },
              reset: function() { draft = []; },
              commit: function(options) {
                return call('schedule_commit', {
                  termId: (options && options.termId) || '',
                  courses: draft.slice()
                });
              }
            }
          };
        })();
        """
        handler.controller.addUserScript(
            WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
    }

    private func handle(_ message: [String: Any]) {
        guard let name = message["name"] as? String,
              let id = message["id"] as? String else { return }
        let payload = message["payload"] as? [String: Any] ?? [:]

        switch name {
        case "schedule_commit":
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                respond(id, ok: false, value: "missing draft")
                return
            }
            do {
                let draft = try decodeScheduleDraft(json)
                let parsed = try coursesFromDraft(draft, limits: .init())
                courses = parsed
                status = .found(parsed.count)
                respond(id, ok: true, value: "accepted")
            } catch {
                status = .failed(String(localized: "school.error.invalid"))
                respond(id, ok: false, value: "invalid draft")
            }

        case "log":
            respond(id, ok: true, value: "ok")

        default:
            respond(id, ok: false, value: "unsupported")
        }
    }

    private func respond(_ id: String, ok: Bool, value: String) {
        let literal = Self.jsLiteral(value)
        webView.evaluateJavaScript("window.__csResolve('\(id)', \(ok), \(literal));", completionHandler: nil)
    }

    private func handleExtractorResult(_ result: Any?) {
        if let dict = result as? [String: Any], dict["hold"] as? Bool == true {
            let reason = dict["error"] as? String ?? "no_table"
            status = .failed(String(format: String(localized: "school.error.extract"), reason))
            return
        }
        // The extractor commits through ctx.schedule.commit, which sets `courses`.
        if courses.isEmpty {
            status = .failed(String(localized: "school.error.noCourses"))
        } else {
            status = .found(courses.count)
        }
    }

    // MARK: - Assets

    private static func loadExtractor() -> String {
        guard let url = Bundle.main.url(forResource: "generic-timetable", withExtension: "js"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }

    private static let runnerPrelude = """
    if (!window.ctx) { return { hold: true, error: 'no_bridge' }; }
    """

    private static func jsLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return text
    }
}

extension SchoolPortalController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if status == .loading { status = .ready }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        status = .failed(error.localizedDescription)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "about" || SchoolPortalCatalog.isAllowed(url, for: school) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

/// Holds the user content controller and forwards bridge messages to the owner.
@MainActor
private final class MessageBridge {
    let controller = WKUserContentController()
    var onMessage: (([String: Any]) -> Void)?
}

extension SchoolPortalController: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }
        handler.onMessage?(body)
    }
}

private struct SchoolWebView: UIViewRepresentable {

    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
