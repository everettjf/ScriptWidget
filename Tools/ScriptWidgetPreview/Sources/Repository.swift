import Foundation

/// Locates the repository and the comparison corpus shared with
/// Web/preview-engine (test/parity/corpus.js and test/render/cases.json).
enum Repository {
    static let root: URL = {
        if let override = ProcessInfo.processInfo.environment["SCRIPTWIDGET_REPO"] {
            return URL(fileURLWithPath: override)
        }
        // Tools/ScriptWidgetPreview/Sources/Repository.swift -> repository root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
    }()

    static let engine = root.appendingPathComponent("Web/preview-engine")
    static let supportBundle = root.appendingPathComponent("Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle")

    static var prelude: String {
        (try? String(contentsOf: engine.appendingPathComponent("test/parity/prelude.js"), encoding: .utf8)) ?? ""
    }

    struct Entry: Identifiable, Hashable {
        let id: String
        let directory: URL?
        let inlineSource: String?
        let preferredFamily: String?
        let dark: Bool
    }

    static func corpus() -> [Entry] {
        var entries: [Entry] = []
        let roots = [
            ("api", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/api"),
            ("component", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/component"),
            ("template", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/template"),
            ("gallery", "Gallery/widgets"),
        ]
        for (prefix, relative) in roots {
            let folder = root.appendingPathComponent(relative)
            let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
            for name in names {
                let directory = folder.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("main.jsx").path) else { continue }
                entries.append(Entry(id: "\(prefix)/\(name)", directory: directory, inlineSource: nil, preferredFamily: nil, dark: false))
            }
        }
        let casesURL = engine.appendingPathComponent("test/render/cases.json")
        if let data = try? Data(contentsOf: casesURL),
           let cases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in cases {
                guard let name = item["name"] as? String, let source = item["source"] as? String else { continue }
                entries.append(Entry(id: "case/\(name)", directory: nil, inlineSource: source,
                                     preferredFamily: item["size"] as? String, dark: item["dark"] as? Bool ?? false))
            }
        }
        let catalogURL = engine.appendingPathComponent("test/catalog/catalog.json")
        if let data = try? Data(contentsOf: catalogURL),
           let catalog = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in catalog {
                guard let id = item["id"] as? String, let source = item["source"] as? String else { continue }
                entries.append(Entry(id: "catalog/\(id)", directory: nil, inlineSource: source,
                                     preferredFamily: item["size"] as? String, dark: item["dark"] as? Bool ?? false))
            }
        }
        return entries
    }

    /// Text files and image resources of a package directory, keyed by
    /// package-relative path, as the web engine expects them.
    static func packageFiles(_ directory: URL) -> (files: [String: String], resources: [String: String]) {
        var files: [String: String] = [:]
        var resources: [String: String] = [:]
        let imageTypes = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp", "gif": "image/gif"]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return (files, resources)
        }
        for case let url as URL in enumerator {
            let relative = url.path.replacingOccurrences(of: directory.path + "/", with: "")
            if relative.hasPrefix("__Build") { continue }
            let ext = url.pathExtension.lowercased()
            if ["js", "jsx", "json", "txt", "md", "csv", "svg"].contains(ext), let text = try? String(contentsOf: url, encoding: .utf8) {
                files[relative] = text
            } else if let type = imageTypes[ext], let data = try? Data(contentsOf: url) {
                resources[relative] = "data:\(type);base64,\(data.base64EncodedString())"
            }
        }
        return (files, resources)
    }
}

/// macOS widget sizes shared with the web engine's "macos" profile.
enum PreviewFamily: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge
    var id: String { rawValue }
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 170, height: 170)
        case .medium: return CGSize(width: 329, height: 170)
        case .large: return CGSize(width: 329, height: 345)
        case .extraLarge: return CGSize(width: 639, height: 345)
        }
    }
}
