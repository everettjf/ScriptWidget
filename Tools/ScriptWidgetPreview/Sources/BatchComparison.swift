import Foundation

/// `ScriptWidgetPreview --batch <dir>`: renders the corpus natively and with
/// the web engine and writes native/, web/, diff/ PNGs and report.json.
@MainActor
enum BatchComparison {
    static func run(output: URL, filter: String, families: [String]) async -> Int32 {
        let fileManager = FileManager.default
        for folder in ["native", "web", "diff"] {
            try? fileManager.createDirectory(at: output.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        let web = WebRenderer()
        do { try await web.prepare() } catch {
            FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
            return 2
        }
        var rows: [[String: Any]] = []
        for entry in Repository.corpus() where filter.isEmpty || entry.id.hasPrefix(filter) {
            if let directory = entry.directory,
               let source = try? String(contentsOf: directory.appendingPathComponent("main.jsx"), encoding: .utf8),
               // Network responses are shared with the web engine (WebRenderer);
               // location, health, and data-source values are not.
               ["$location.", "$health.", "$dataSource."].contains(where: source.contains) { continue }
            let entryFamilies = entry.preferredFamily.map { [$0] } ?? families
            for name in entryFamilies {
                guard let family = PreviewFamily(rawValue: name) else { continue }
                let id = "\(entry.id)@\(name)"
                let result = await CompareModel.compare(entry, family: family, dark: entry.dark, web: web)
                let file = id.replacingOccurrences(of: "/", with: "__").replacingOccurrences(of: " ", with: "_") + ".png"
                if let image = result.native { ImageDiff.writePNG(image, to: output.appendingPathComponent("native/\(file)")) }
                if let image = result.web { ImageDiff.writePNG(image, to: output.appendingPathComponent("web/\(file)")) }
                if let image = result.diff { ImageDiff.writePNG(image, to: output.appendingPathComponent("diff/\(file)")) }
                var row: [String: Any] = ["name": id, "file": file]
                if let percent = result.percent { row["percent"] = (percent * 100).rounded() / 100 }
                if let error = result.nativeError { row["nativeError"] = error }
                if let error = result.webError { row["webError"] = error }
                rows.append(row)
                print(String(format: "%7.2f%%  %@", result.percent ?? -1, id))
            }
        }
        let percents = rows.compactMap { $0["percent"] as? Double }.sorted()
        let median = percents.isEmpty ? 0 : percents[percents.count / 2]
        let summary: [String: Any] = [
            "platform": "macos", "renders": rows.count, "compared": percents.count, "median": median,
            "within5": percents.filter { $0 <= 5 }.count, "within20": percents.filter { $0 <= 20 }.count, "results": rows,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: output.appendingPathComponent("report.json"))
        }
        print(String(format: "renders %d compared %d median %.2f%% <=5%% %d <=20%% %d", rows.count, percents.count, median,
                     summary["within5"] as! Int, summary["within20"] as! Int))
        return 0
    }
}
