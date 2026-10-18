import AppKit
import SwiftUI

/// Renders one package both ways and keeps the result for ContentView.
@MainActor
final class CompareModel: ObservableObject {
    struct Comparison {
        var native: CGImage?
        var web: CGImage?
        var diff: CGImage?
        var percent: Double?
        var nativeError: String?
        var webError: String?
        var diagnostics: [String] = []
        var nativeMilliseconds: Double = 0
        var webMilliseconds: Double = 0
    }

    @Published var entries: [Repository.Entry] = Repository.corpus()
    @Published var selection: Repository.Entry.ID?
    @Published var family: PreviewFamily = .medium
    @Published var dark = false
    @Published var comparison = Comparison()
    @Published var busy = false

    let web = WebRenderer()
    private var generation = 0

    var selectedEntry: Repository.Entry? { entries.first { $0.id == selection } }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Compare"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let entry = Repository.Entry(id: "folder/\(url.lastPathComponent)", directory: url, inlineSource: nil, preferredFamily: nil, dark: false)
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        selection = entry.id
        refresh()
    }

    func refresh() {
        guard let entry = selectedEntry else { return }
        generation += 1
        let current = generation
        busy = true
        Task {
            let result = await Self.compare(entry, family: family, dark: dark || entry.dark, web: web)
            guard current == generation else { return }
            comparison = result
            busy = false
        }
    }

    static func compare(_ entry: Repository.Entry, family: PreviewFamily, dark: Bool, web: WebRenderer) async -> Comparison {
        let prelude = Repository.prelude
        let package: ScriptWidgetPackage
        let source: String
        var files: [String: String]
        var resources: [String: String] = [:]
        if let directory = entry.directory {
            package = ScriptWidgetPackage(path: directory, readonly: true)
            source = package.readMainFile().0 ?? ""
            (files, resources) = Repository.packageFiles(directory)
        } else {
            package = ScriptWidgetPackage(path: FileManager.default.temporaryDirectory, readonly: true)
            source = entry.inlineSource ?? ""
            files = ["main.jsx": source]
        }
        if entry.directory == nil { files["main.jsx"] = source }
        var comparison = Comparison()
        let native = await NativeRenderer.render(source: prelude + source, package: package, family: family, dark: dark)
        comparison.native = native.image
        comparison.nativeError = native.error
        comparison.nativeMilliseconds = native.milliseconds
        let rendered = await web.render(files: files, resources: resources, family: family, dark: dark, prelude: prelude)
        comparison.web = rendered.image
        comparison.webError = rendered.error
        comparison.diagnostics = rendered.diagnostics
        comparison.webMilliseconds = rendered.milliseconds
        if let a = native.image, let b = rendered.image {
            let diff = ImageDiff.compare(a, b)
            comparison.diff = diff.image
            comparison.percent = diff.percent
        }
        return comparison
    }
}
