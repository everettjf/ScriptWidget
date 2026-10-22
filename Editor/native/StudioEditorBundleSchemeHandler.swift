import Foundation
import WebKit

/// Serves only signed editor bundle resources. Widget source remains editor
/// text and is never served or executed in this realm.
final class StudioEditorBundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "scriptwidget-editor"
    static let origin = "scriptwidget-editor://studio"
    static let indexURL = URL(string: origin + "/index.html")!
    static let maximumResourceBytes = 8 * 1024 * 1024
    private let root: URL?
    override convenience init() {
        let bundleURL = Bundle.main.url(forResource: "StudioEditor", withExtension: "bundle")
        self.init(root: bundleURL.flatMap { Bundle(url: $0)?.resourceURL })
    }
    init(root: URL?) {
        self.root = root?.isFileURL == true ? root?.standardizedFileURL.resolvingSymlinksInPath() : nil
        super.init()
    }
    func resource(for request: URLRequest) throws -> (data: Data, mime: String) {
        guard request.httpMethod == nil || request.httpMethod == "GET",
              let url = request.url, url.scheme == Self.scheme, url.host == "studio",
              url.user == nil, url.password == nil, url.port == nil, url.query == nil, url.fragment == nil,
              let encoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath,
              encoded.range(of: "%(?:2f|5c|00)", options: [.regularExpression,.caseInsensitive]) == nil,
              let path = encoded.removingPercentEncoding, path.hasPrefix("/"), path.utf8.count <= 512,
              let root else { throw URLError(.badURL) }
        let components = String(path.dropFirst()).split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty, components.count <= 8,
              components.allSatisfy({ $0 != "." && $0 != ".." && $0.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,180}$", options: .regularExpression) != nil }) else { throw URLError(.noPermissionsToReadFile) }
        var target = root
        for component in components {
            target.appendPathComponent(component)
            let values = try target.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw URLError(.noPermissionsToReadFile) }
        }
        guard target.resolvingSymlinksInPath().path.hasPrefix(root.path + "/") else { throw URLError(.noPermissionsToReadFile) }
        let types = ["html":"text/html; charset=utf-8", "js":"application/javascript; charset=utf-8", "mjs":"application/javascript; charset=utf-8",
                     "css":"text/css; charset=utf-8", "json":"application/json; charset=utf-8", "map":"application/json; charset=utf-8",
                     "svg":"image/svg+xml", "png":"image/png", "jpg":"image/jpeg", "jpeg":"image/jpeg", "gif":"image/gif",
                     "woff":"font/woff", "woff2":"font/woff2", "ttf":"font/ttf", "otf":"font/otf", "wasm":"application/wasm"]
        guard let mime = types[target.pathExtension.lowercased()] else { throw URLError(.unsupportedURL) }
        let values = try target.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= Self.maximumResourceBytes else { throw URLError(.dataLengthExceedsMaximum) }
        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        guard (attributes[.referenceCount] as? NSNumber)?.intValue == 1 else { throw URLError(.noPermissionsToReadFile) }
        let data = try Data(contentsOf: target)
        guard data.count <= Self.maximumResourceBytes else { throw URLError(.dataLengthExceedsMaximum) }
        return (data, mime)
    }
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        do {
            let resource = try resource(for: urlSchemeTask.request)
            guard let url = urlSchemeTask.request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                    "Content-Type":resource.mime, "Content-Length":String(resource.data.count),
                    // WebKit can give custom schemes an opaque module origin.
                    // These are public, fixed bundle assets, with no cookies,
                    // user files or credential-bearing responses.
                    "Access-Control-Allow-Origin":"*", "X-Content-Type-Options":"nosniff"
                  ]) else { throw URLError(.badURL) }
            urlSchemeTask.didReceive(response); urlSchemeTask.didReceive(resource.data); urlSchemeTask.didFinish()
        } catch { urlSchemeTask.didFailWithError(URLError(.resourceUnavailable)) }
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { }
}
