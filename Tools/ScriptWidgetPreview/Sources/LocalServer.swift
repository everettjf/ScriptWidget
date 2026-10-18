import Foundation
import Network

/// Serves Web/preview-engine to the embedded WKWebView on 127.0.0.1, with
/// the routes src/cli/render.html expects (/__sandbox-sources.js and
/// /__runtime/*). Read-only and bound to the loopback interface.
final class LocalServer {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    private let queue = DispatchQueue(label: "scriptwidget.preview.server")

    func start() async throws -> UInt16 {
        if port != 0 { return port }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    let port = listener.port?.rawValue ?? 0
                    self?.port = port
                    continuation.resume(returning: port)
                    listener.stateUpdateHandler = nil
                case .failed(let error):
                    continuation.resume(throwing: error)
                    listener.stateUpdateHandler = nil
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8),
                  let line = request.split(separator: "\r\n").first else { connection.cancel(); return }
            let parts = line.split(separator: " ")
            let rawPath = parts.count > 1 ? String(parts[1]) : "/"
            let path = (rawPath.split(separator: "?").first.map(String.init) ?? "/").removingPercentEncoding ?? "/"
            let (status, type, body) = self.response(for: path)
            var header = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            if status != "200 OK" { header = header.replacingOccurrences(of: "Content-Type: \(type)", with: "Content-Type: text/plain") }
            connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    private func response(for path: String) -> (String, String, Data) {
        let notFound = ("404 Not Found", "text/plain", Data("Not found".utf8))
        let file: URL
        if path == "/__sandbox-sources.js" {
            file = Repository.engine.appendingPathComponent("dist/sandbox-sources.js")
        } else if path.hasPrefix("/__runtime/") {
            file = Repository.supportBundle.appendingPathComponent(String(path.dropFirst("/__runtime/".count)))
        } else {
            file = Repository.engine.appendingPathComponent(String(path.dropFirst()))
        }
        // Resolve ".." and symlinks before checking the two served roots.
        let resolved = file.standardizedFileURL.resolvingSymlinksInPath().path
        let allowed = [Repository.engine, Repository.supportBundle].map { $0.standardizedFileURL.resolvingSymlinksInPath().path + "/" }
        guard allowed.contains(where: { resolved.hasPrefix($0) }), let data = try? Data(contentsOf: file) else { return notFound }
        let types = ["html": "text/html", "js": "text/javascript", "mjs": "text/javascript", "json": "application/json", "css": "text/css", "woff2": "font/woff2"]
        return ("200 OK", types[file.pathExtension.lowercased()] ?? "application/octet-stream", data)
    }
}
