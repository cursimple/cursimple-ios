import CurSimpleCore
import Foundation
import Observation
import WebKit

/// Runs a school plugin's `main.js` inside a restricted web view and exposes the
/// `ctx` bridge the plugin expects. The host owns navigation, permissions and
/// data writes; the bundle owns the school protocol.
@MainActor
@Observable
final class PluginWebRunner: NSObject {

    enum State: Equatable {
        case idle
        case loading
        case needsLogin
        case syncing
        case finished(courseCount: Int)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var log: [String] = []
    private(set) var lastDraft: [CourseItem] = []

    let manifest: PluginManifest
    private let webView: WKWebView
    private let userContentController = WKUserContentController()
    private var script: String = ""
    private var timeoutTask: Task<Void, Never>?

    init(manifest: PluginManifest, script: String) {
        self.manifest = manifest
        self.script = script
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        userContentController.add(self, name: "cursimple")
        webView.navigationDelegate = self
        installBridge()
    }

    var webViewForDisplay: WKWebView { webView }

    // MARK: - Lifecycle

    func start() {
        guard let url = startURL else {
            state = .failed(String(localized: "plugin.error.noStartUrl"))
            return
        }
        state = .loading
        append("open \(url.absoluteString)")
        webView.load(URLRequest(url: url))
        startTimeout()
    }

    func reload() {
        webView.reload()
        startTimeout()
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        webView.stopLoading()
    }

    private var startURL: URL? {
        if let raw = manifest.startUrl, let url = URL(string: raw) {
            return url
        }
        guard let host = manifest.allowedHosts.first else { return nil }
        return URL(string: "https://\(host)/")
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        let seconds = max(manifest.limits.timeoutMs, 5_000) / 1000
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.state == .loading else { return }
            self.state = .failed(String(localized: "plugin.error.timeout"))
        }
    }

    // MARK: - Bridge

    /// The plugin entry is an ES module exporting `run(ctx)`; `ctx` exposes the
    /// documented capabilities and every call posts back to the host.
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
            readDOM: function(selector) { return call('read_dom', { selector: selector }); },
            getCookies: function() { return call('read_cookies', {}); },
            setUserAgent: function(value) { return call('set_user_agent', { value: value }); },
            fetch: function(url, options) { return call('fetch', { url: url, options: options || null }); },
            schedule: {
              addCourse: function(course) { draft.push(course || {}); return draft.length; },
              reset: function() { draft = []; },
              commit: function(options) {
                var payload = {
                  termId: (options && options.termId) || '',
                  courses: draft.slice()
                };
                return call('schedule_commit', payload);
              }
            }
          };

          window.__csRun = async function(source) {
            try {
              var blob = new Blob([source], { type: 'text/javascript' });
              var url = URL.createObjectURL(blob);
              var mod = await import(url);
              URL.revokeObjectURL(url);
              if (typeof mod.run !== 'function') { throw new Error('entry must export run(ctx)'); }
              return await mod.run(window.ctx);
            } catch (error) {
              window.webkit.messageHandlers.cursimple.postMessage({
                id: 'run', name: 'run_error', payload: { text: String(error && error.message || error) }
              });
              return null;
            }
          };
        })();
        """
        userContentController.addUserScript(
            WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
    }

    private func runPluginScript() {
        guard !script.isEmpty else { return }
        guard let literal = jsonLiteral(script) as String? else { return }
        let js = "window.__csRun(\(literal));"
        webView.evaluateJavaScript(js) { [weak self] _, error in
            guard let self, let error else { return }
            self.append("script error: \(error.localizedDescription)")
        }
    }

    private func append(_ line: String) {
        log.append(line)
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    private func respond(id: String, ok: Bool, value: String) {
        let payload = ok ? value : value
        let js = "window.__csResolve('\(id)', \(ok), \(jsonLiteral(payload)))"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func jsonLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return text
    }
}

// MARK: - Bridge messages

extension PluginWebRunner: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let name = body["name"] as? String else {
            return
        }
        let payload = body["payload"] as? [String: Any] ?? [:]

        switch name {
        case "log":
            append(payload["text"] as? String ?? "")

        case "read_dom":
            let selector = payload["selector"] as? String ?? "body"
            readDOM(selector: selector) { [weak self] text in
                self?.respond(id: id, ok: true, value: text)
            }

        case "read_cookies":
            guard manifest.has(.webReadCookies) else {
                respond(id: id, ok: false, value: "permission denied")
                return
            }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                let allowed = cookies.filter { cookie in
                    self?.manifest.allowedHosts.contains { cookie.domain.hasSuffix($0) } ?? false
                }
                let text = allowed
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")
                self?.respond(id: id, ok: true, value: text)
            }

        case "set_user_agent":
            let value = payload["value"] as? String ?? ""
            webView.customUserAgent = value
            respond(id: id, ok: true, value: "ok")

        case "fetch":
            guard manifest.has(.networkFetch),
                  let raw = payload["url"] as? String,
                  let url = URL(string: raw),
                  let host = url.host,
                  manifest.allowedHosts.contains(where: {
                      host.caseInsensitiveCompare($0) == .orderedSame
                          || host.lowercased().hasSuffix("." + $0.lowercased())
                  }) else {
                respond(id: id, ok: false, value: "blocked")
                return
            }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.respond(id: id, ok: false, value: error.localizedDescription)
                    } else {
                        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                        self.respond(id: id, ok: true, value: text)
                    }
                }
            }.resume()

        case "schedule_commit":
            guard manifest.has(.scheduleWrite) else {
                respond(id: id, ok: false, value: "permission denied")
                return
            }
            guard let draftJSON = jsonString(payload) else {
                respond(id: id, ok: false, value: "missing draft")
                return
            }
            handleScheduleDraft(draftJSON, id: id)

        case "run_error":
            let text = payload["text"] as? String ?? "unknown error"
            append("run error: \(text)")
            state = .failed(text)

        default:
            append("unknown bridge call: \(name)")
            respond(id: id, ok: false, value: "unknown call")
        }
    }

    private func jsonString(_ payload: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private func readDOM(selector: String, completion: @escaping (String) -> Void) {
        guard manifest.has(.webReadDOM) else {
            completion("")
            return
        }
        let js = """
        (function() {
          try {
            var el = document.querySelector(\(jsonLiteral(selector)));
            return el ? (el.innerText || el.textContent || '') : '';
          } catch (e) { return ''; }
        })();
        """
        webView.evaluateJavaScript(js) { text, _ in
            completion(text as? String ?? "")
        }
    }

    private func handleScheduleDraft(_ json: String, id: String) {
        do {
            let draft = try decodeScheduleDraft(json)
            let courses = try coursesFromDraft(draft, limits: manifest.limits)
            guard courses.count <= manifest.limits.maxCourses else {
                throw ScheduleDraftError.tooManyCourses
            }
            lastDraft = courses
            state = .finished(courseCount: courses.count)
            append("draft accepted: \(courses.count) courses")
            respond(id: id, ok: true, value: "accepted")
        } catch {
            state = .failed(String(localized: "plugin.error.invalidDraft"))
            append("draft rejected: \(error)")
            respond(id: id, ok: false, value: "invalid draft")
        }
    }
}

// MARK: - Navigation

extension PluginWebRunner: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        append("loaded \(webView.url?.absoluteString ?? "")")
        runPluginScript()
        if state == .loading {
            state = .needsLogin
        }
        timeoutTask?.cancel()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        state = .failed(error.localizedDescription)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        state = .failed(error.localizedDescription)
    }

    /// Keep navigation inside the declared hosts.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "about" {
            decisionHandler(.allow)
            return
        }
        guard let host = url.host,
              manifest.allowedHosts.contains(where: {
                  host.caseInsensitiveCompare($0) == .orderedSame
                      || host.lowercased().hasSuffix("." + $0.lowercased())
              }) else {
            append("blocked navigation: \(url.absoluteString)")
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
