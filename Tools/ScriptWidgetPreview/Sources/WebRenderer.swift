import AppKit
import WebKit

/// Drives Web/preview-engine/src/cli/render.html in an offscreen WKWebView:
/// the package runs in the engine's sandboxed frame, the renderer draws the
/// widget, and the widget's rectangle is snapshotted.
@MainActor
final class WebRenderer: NSObject, WKNavigationDelegate {
    private let server = LocalServer()
    private var webView: WKWebView?
    private var window: NSWindow?
    private var loaded: CheckedContinuation<Void, Error>?

    struct Result {
        let image: CGImage?
        let error: String?
        let diagnostics: [String]
        let milliseconds: Double
    }

    func prepare() async throws {
        if webView != nil { return }
        let port = try await server.start()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 900), configuration: configuration)
        webView.navigationDelegate = self
        // WebKit only paints views that live in a window; keep it offscreen.
        let window = NSWindow(contentRect: CGRect(x: -10000, y: -10000, width: 900, height: 900), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = webView
        window.orderBack(nil)
        self.window = window
        self.webView = webView
        let url = URL(string: "http://127.0.0.1:\(port)/src/cli/render.html")!
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loaded = continuation
            webView.load(URLRequest(url: url))
        }
        for _ in 0..<300 {
            if (try? await webView.evaluateJavaScript("window.__ready === true")) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw NSError(domain: "ScriptWidgetPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "The web preview runtime did not start. Run `npm run build` in Web/preview-engine."])
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in loaded?.resume(); loaded = nil }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in loaded?.resume(throwing: error); loaded = nil }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in loaded?.resume(throwing: error); loaded = nil }
    }

    func render(files: [String: String], resources: [String: String], family: PreviewFamily, dark: Bool, prelude: String) async -> Result {
        let started = Date()
        do {
            try await prepare()
            guard let webView else { throw NSError(domain: "ScriptWidgetPreview", code: 2) }
            var manifest: Any = NSNull()
            if let text = files["widget.json"], let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) { manifest = object }
            let entry = (manifest as? [String: Any])?["entry"] as? String ?? "main.jsx"
            let job: [String: Any] = [
                "execute": [
                    "files": files, "entry": entry, "manifest": manifest, "prelude": prelude,
                    "environments": ["widget-size": family.rawValue, "widget-param": "", "widget-rendering-mode": "fullColor"],
                    "preview": ["appearance": dark ? "dark" : "light"], "fixtures": [String: Any](),
                ],
                "render": ["family": family.rawValue, "profile": "macos", "appearance": dark ? "dark" : "light", "resources": resources],
            ]
            let value = try await webView.callAsyncJavaScript("return await window.__render(job)", arguments: ["job": job], contentWorld: .page)
            guard let output = value as? [String: Any] else { throw NSError(domain: "ScriptWidgetPreview", code: 3) }
            let diagnostics = ((output["diagnostics"] as? [[String: Any]] ?? []) + (output["renderDiagnostics"] as? [[String: Any]] ?? []))
                .compactMap { $0["message"] as? String }
            if let error = output["error"] as? [String: Any] {
                return Result(image: nil, error: "\(error["kind"] ?? "error"): \(error["message"] ?? "")", diagnostics: diagnostics, milliseconds: Date().timeIntervalSince(started) * 1000)
            }
            guard let box = output["box"] as? [String: Double] else { throw NSError(domain: "ScriptWidgetPreview", code: 4) }
            let configuration = WKSnapshotConfiguration()
            configuration.rect = CGRect(x: box["x"] ?? 0, y: box["y"] ?? 0, width: box["width"] ?? 0, height: box["height"] ?? 0)
            configuration.afterScreenUpdates = true
            let snapshot = try await webView.takeSnapshot(configuration: configuration)
            let image = Self.bitmap(snapshot, width: Int((box["width"] ?? 0) * 2), height: Int((box["height"] ?? 0) * 2))
            return Result(image: image, error: nil, diagnostics: diagnostics, milliseconds: Date().timeIntervalSince(started) * 1000)
        } catch {
            return Result(image: nil, error: error.localizedDescription, diagnostics: [], milliseconds: Date().timeIntervalSince(started) * 1000)
        }
    }

    /// Normalizes the snapshot to an exact 2x RGBA bitmap.
    static func bitmap(_ image: NSImage, width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}
