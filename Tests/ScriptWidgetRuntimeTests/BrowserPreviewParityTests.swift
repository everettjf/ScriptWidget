//
//  BrowserPreviewParityTests.swift
//  ScriptWidgetRuntimeTests
//
//  Emits the canonical resolved-element-tree JSON that the browser preview
//  engine (Web/preview-engine) must reproduce byte for byte. Run with
//  TEST_RUNNER_SCRIPTWIDGET_UPDATE_PARITY=1 to rewrite
//  Web/preview-engine/test/parity/native-trees.json, then run
//  `npm test` in Web/preview-engine to compare.
//

import Foundation
import JavaScriptCore
import XCTest
@testable import ScriptWidget

/// Canonical tree JSON shared with `encodeElement` in Web/preview-engine/src/kernel.js.
/// Numbers are formatted by JavaScriptCore's Number#toString so both hosts
/// use the ECMAScript algorithm; keys are sorted by UTF-16 code units.
enum ScriptWidgetElementTreeJSON {
    private static let numberContext = JSContext()!

    static func encode(_ element: ScriptWidgetRuntimeElement) -> String {
        let tag = element.tagAsString().map(string) ?? #"{"$function":true}"#
        let props = element.props.map(dictionary) ?? "null"
        let children = element.children.map { "[" + $0.map(value).joined(separator: ",") + "]" } ?? "null"
        return #"{"$element":"# + tag + #","props":"# + props + #","children":"# + children + "}"
    }

    static func value(_ value: Any) -> String {
        switch value {
        case let element as ScriptWidgetRuntimeElement: return encode(element)
        case is NSNull: return "null"
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            return self.number(number.doubleValue)
        case let text as String: return string(text)
        case let date as Date: return #"{"$date":"# + number(date.timeIntervalSince1970 * 1000) + "}"
        case let array as [Any]: return "[" + array.map(self.value).joined(separator: ",") + "]"
        case let map as [AnyHashable: Any]: return #"{"$dict":"# + dictionary(map) + "}"
        default: return #"{"$unknown":"# + string(String(describing: type(of: value))) + "}"
        }
    }

    static func dictionary(_ map: [AnyHashable: Any]) -> String {
        let keys = map.keys.map { "\($0.base)" }
        let sorted = keys.sorted { Array($0.utf16).lexicographicallyPrecedes(Array($1.utf16)) }
        var lookup: [String: Any] = [:]
        for (key, item) in map { lookup["\(key.base)"] = item }
        return "{" + sorted.map { string($0) + ":" + value(lookup[$0]!) }.joined(separator: ",") + "}"
    }

    static func number(_ double: Double) -> String {
        if double.isNaN { return #"{"$number":"NaN"}"# }
        if double == .infinity { return #"{"$number":"Infinity"}"# }
        if double == -.infinity { return #"{"$number":"-Infinity"}"# }
        if double == 0, double.sign == .minus { return #"{"$number":"-0"}"# }
        return JSValue(double: double, in: numberContext).toString()
    }

    /// JSON.stringify string escaping, including lone-surrogate escapes.
    static func string(_ text: String) -> String {
        var result = "\""
        let units = Array(text.utf16)
        var index = 0
        func hex(_ unit: UInt16) -> String {
            let digits = String(unit, radix: 16)
            return "\\u" + String(repeating: "0", count: 4 - digits.count) + digits
        }
        while index < units.count {
            let unit = units[index]
            switch unit {
            case 0x22: result += "\\\""
            case 0x5C: result += "\\\\"
            case 0x08: result += "\\b"
            case 0x0C: result += "\\f"
            case 0x0A: result += "\\n"
            case 0x0D: result += "\\r"
            case 0x09: result += "\\t"
            case 0..<0x20: result += hex(unit)
            case 0xD800...0xDBFF:
                if index + 1 < units.count, (0xDC00...0xDFFF).contains(units[index + 1]) {
                    result += String(utf16CodeUnits: [unit, units[index + 1]], count: 2)
                    index += 1
                } else {
                    result += hex(unit)
                }
            case 0xDC00...0xDFFF: result += hex(unit)
            default: result += String(utf16CodeUnits: [unit], count: 1)
            }
            index += 1
        }
        return result + "\""
    }
}

#if os(iOS)
import SwiftUI
import UIKit

/// Widget family sizes for the 393-point iPhone class (Apple HIG), shared with
/// Web/preview-engine/src/render/profiles.js.
enum BrowserPreviewSnapshotProfile {
    static func size(_ family: String) -> CGSize {
        switch family {
        case "small": return CGSize(width: 158, height: 158)
        case "large": return CGSize(width: 338, height: 354)
        case "accessoryCircular": return CGSize(width: 72, height: 72)
        case "accessoryRectangular": return CGSize(width: 170, height: 72)
        case "accessoryInline": return CGSize(width: 250, height: 30)
        default: return CGSize(width: 338, height: 158)
        }
    }
}

/// Mirrors ScriptWidgetWidgetElementRootView: the root element's background
/// becomes the widget container background and the root view is centered.
struct BrowserPreviewSnapshotView: View {
    let element: ScriptWidgetRuntimeElement
    let context: ScriptWidgetElementContext
    let size: CGSize

    var body: some View {
        let background = element.getPropString("background").map(ScriptWidgetAttributeColor.init) ?? ScriptWidgetAttributeColor()
        ZStack {
            if let color = background.color { color } else if let gradient = background.gradient { gradient } else { Color(uiColor: .systemBackground) }
            ScriptWidgetElementView(element: element, context: context)
        }
        .frame(width: size.width, height: size.height)
    }
}
#endif

final class BrowserPreviewParityTests: XCTestCase {
    #if os(iOS)
    /// Writes native PNGs for the corpus and Web/preview-engine/test/render/cases.json
    /// to Web/preview-engine/dist/native-snapshots when
    /// TEST_RUNNER_SCRIPTWIDGET_EXPORT_SNAPSHOTS=1.
    @MainActor
    func testExportNativeSnapshots() async throws {
        guard ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_SNAPSHOTS"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_SCRIPTWIDGET_EXPORT_SNAPSHOTS=1 to export native snapshots")
        }
        let output = Self.repositoryRoot.appendingPathComponent("Web/preview-engine/dist/native-snapshots")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let prelude = try String(contentsOf: Self.parityDirectory.appendingPathComponent("prelude.js"), encoding: .utf8)
        var jobs: [(name: String, family: String, source: String, package: ScriptWidgetPackage, dark: Bool)] = []
        for (name, directory) in try Self.corpusPackages() {
            let package = ScriptWidgetPackage(path: directory, readonly: true)
            guard let source = package.readMainFile().0, !Self.usesLiveData(source) else { continue }
            for family in ["small", "medium", "large"] { jobs.append(("\(name)@\(family)", family, prelude + source, package, false)) }
        }
        let casesURL = Self.repositoryRoot.appendingPathComponent("Web/preview-engine/test/render/cases.json")
        let cases = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: casesURL)) as? [[String: Any]])
        let scratch = ScriptWidgetPackage(path: FileManager.default.temporaryDirectory, readonly: true)
        for item in cases {
            let family = item["size"] as? String ?? "medium"
            jobs.append(("case/\(item["name"] as? String ?? "")@\(family)", family, prelude + (item["source"] as? String ?? ""), scratch, item["dark"] as? Bool ?? false))
        }
        let filter = ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_FILTER"] ?? ""
        for job in jobs where filter.isEmpty || job.name.hasPrefix(filter) {
            let runtime = ScriptWidgetRuntime(package: job.package, environments: ["widget-size": job.family, "widget-param": ""])
            let result = await Task.detached { runtime.executeJSXSyncForWidget(job.source) }.value
            guard let element = result.0 else { continue }
            let context = ScriptWidgetElementContext(runtime: runtime, debugMode: false, scriptName: job.name, scriptParameter: "",
                                                     package: job.package, containerBackgroundElement: element)
            let renderer = ImageRenderer(content: BrowserPreviewSnapshotView(element: element, context: context,
                                                                             size: BrowserPreviewSnapshotProfile.size(job.family))
                .environment(\.colorScheme, job.dark ? .dark : .light))
            renderer.scale = 2
            guard let data = renderer.uiImage?.pngData() else { continue }
            let fileName = job.name.replacingOccurrences(of: "/", with: "__").replacingOccurrences(of: " ", with: "_") + ".png"
            try data.write(to: output.appendingPathComponent(fileName), options: .atomic)
        }
    }
    #endif


    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let parityDirectory = repositoryRoot.appendingPathComponent("Web/preview-engine/test/parity")

    /// Package directories shared with Web/preview-engine/test/parity/corpus.js.
    static func corpusPackages() throws -> [(name: String, directory: URL)] {
        let roots = [
            ("api", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/api"),
            ("component", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/component"),
            ("template", "Shared/ScriptWidgetRuntime/Resource/Script.bundle/template"),
            ("gallery", "Gallery/widgets"),
        ]
        var result: [(String, URL)] = []
        for (prefix, relative) in roots {
            let root = repositoryRoot.appendingPathComponent(relative)
            let names = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { !$0.hasPrefix(".") }.sorted()
            for name in names {
                let directory = root.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("main.jsx").path) else { continue }
                result.append(("\(prefix)/\(name)", directory))
            }
        }
        return result
    }

    static func usesLiveData(_ source: String) -> Bool {
        source.contains("fetch(") || source.contains("$http.") || source.contains("$location.") ||
            source.contains("$health.") || source.contains("$dataSource.")
    }

    private func errorKind(_ error: ScriptWidgetError) -> String {
        switch error {
        case .undefinedRender: return "undefinedRender"
        case .internalError: return "internalError"
        case .transformError: return "transformError"
        case .scriptError: return "scriptError"
        case .scriptException: return "scriptException"
        case .resourceLimit: return "resourceLimit"
        }
    }

    func testFontWeightAndDesignPropertiesAreRead() {
        let legacy = ScriptWidgetRuntimeElement(tagString: "text", props: ["font": "title", "weight": "bold", "fontDesign": "rounded"], children: ["x"])
        XCTAssertEqual(ScriptWidgetAttributeFontModifier(legacy).weight, .bold)
        XCTAssertEqual(ScriptWidgetAttributeFontModifier(legacy).design, .rounded)
        let both = ScriptWidgetRuntimeElement(tagString: "text", props: ["weight": "bold", "fontWeight": "light"], children: ["x"])
        XCTAssertEqual(ScriptWidgetAttributeFontModifier(both).weight, .light)
        let gaugeLabel = ScriptWidgetRuntimeElement(tagString: "gauge", props: ["fontWeight": "bold"], children: [])
        XCTAssertNil(ScriptWidgetAttributeFontModifier(gaugeLabel, fontField: "labelFont").weight)
        XCTAssertNil(ScriptWidgetAttributeFontModifier(ScriptWidgetRuntimeElement(tagString: "text", props: ["fontWeight": "huge"], children: [])).weight)
    }

    func testCanonicalEncodingMatchesJavaScriptSemantics() {
        XCTAssertEqual(ScriptWidgetElementTreeJSON.number(1), "1")
        XCTAssertEqual(ScriptWidgetElementTreeJSON.number(0.1 + 0.2), "0.30000000000000004")
        XCTAssertEqual(ScriptWidgetElementTreeJSON.number(1e21), "1e+21")
        XCTAssertEqual(ScriptWidgetElementTreeJSON.number(1e-7), "1e-7")
        XCTAssertEqual(ScriptWidgetElementTreeJSON.number(-0.0), #"{"$number":"-0"}"#)
        XCTAssertEqual(ScriptWidgetElementTreeJSON.string("a\"\\\n\u{1}é😀"), #""a\"\\\n\u0001é😀""#)
    }

    func testBridgeSemanticsProbe() throws {
        let source = """
        $render(<vstack a={1} b={1.5} c={true} d="x" e={null} f={undefined} g={() => 1} h={[1, undefined, null]} i={{ x: 1 }} j={new Date(0)}>
          {"s"}{1}{true}{null}{undefined}{[["n", [2]]]}
        </vstack>);
        """
        let runtime = ScriptWidgetRuntime(package: ScriptWidgetPackage(path: FileManager.default.temporaryDirectory, readonly: true),
                                          environments: ["widget-size": "medium", "widget-param": ""])
        let (element, error) = runtime.executeJSXSyncForWidget(source)
        XCTAssertNil(error)
        let json = ScriptWidgetElementTreeJSON.encode(try XCTUnwrap(element))
        XCTAssertEqual(json, #"{"$element":"vstack","props":{"a":1,"b":1.5,"c":true,"d":"x","e":null,"g":{"$dict":{}},"h":[1,null,null],"i":{"$dict":{"x":1}},"j":{"$date":0}},"children":["s",1,true,null,null,[["n",[2]]]]}"#)
    }

    func testCorpusTreesMatchCheckedInParityFile() throws {
        let prelude = try String(contentsOf: Self.parityDirectory.appendingPathComponent("prelude.js"), encoding: .utf8)
        var entries: [String: Any] = [:]
        for (name, directory) in try Self.corpusPackages() {
            let package = ScriptWidgetPackage(path: directory, readonly: true)
            let source = try XCTUnwrap(package.readMainFile().0, "missing source for \(name)")
            if Self.usesLiveData(source) {
                entries[name] = ["skipped": "live-data"]
                continue
            }
            let runtime = ScriptWidgetRuntime(package: package, environments: ["widget-size": "medium", "widget-param": ""])
            let (element, error) = runtime.executeJSXSyncForWidget(prelude + source)
            if let error {
                entries[name] = ["error": errorKind(error)]
            } else if let element {
                entries[name] = ["tree": ScriptWidgetElementTreeJSON.encode(element)]
            } else {
                entries[name] = ["error": "none"]
            }
        }
        let context = JSContext()!
        let document: [String: Any] = [
            "generator": "BrowserPreviewParityTests.swift",
            "compilerFingerprint": ScriptWidgetBuildContract.compilerFingerprint,
            "runtimeAPIVersion": ScriptWidgetRuntimeContract.apiVersion,
            "timeZone": TimeZone.current.identifier,
            "javaScriptLocale": context.evaluateScript("Intl.DateTimeFormat().resolvedOptions().locale")?.toString() ?? "",
            "entries": entries,
        ]
        let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let output = Self.parityDirectory.appendingPathComponent("native-trees.json")
        if ProcessInfo.processInfo.environment["SCRIPTWIDGET_UPDATE_PARITY"] == "1" {
            try data.write(to: output, options: .atomic)
            return
        }
        guard let existing = try? Data(contentsOf: output) else {
            throw XCTSkip("Run with TEST_RUNNER_SCRIPTWIDGET_UPDATE_PARITY=1 to create native-trees.json")
        }
        let current = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let recorded = try XCTUnwrap(JSONSerialization.jsonObject(with: existing) as? [String: Any])
        // JavaScriptCore reads the process time zone once, so date-formatting
        // templates are only comparable on a machine in the recorded zone.
        guard recorded["timeZone"] as? String == TimeZone.current.identifier else {
            throw XCTSkip("native-trees.json was recorded in \(recorded["timeZone"] ?? "?"); this machine uses \(TimeZone.current.identifier)")
        }
        XCTAssertEqual(NSDictionary(dictionary: current["entries"] as? [String: Any] ?? [:]),
                       NSDictionary(dictionary: recorded["entries"] as? [String: Any] ?? [:]),
                       "Native trees changed. Regenerate native-trees.json and re-run Web/preview-engine parity tests.")
    }
}
