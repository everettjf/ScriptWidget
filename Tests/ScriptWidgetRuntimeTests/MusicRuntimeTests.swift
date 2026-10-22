import Foundation
import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import ScriptWidget

final class MusicRuntimeTests: XCTestCase {
    private final class Provider: ScriptWidgetMusicProviding {
        var available = true
        var status = "authorized"
        var reads = 0
        var beforeReturn: (() -> Void)?
        var snapshot = ScriptWidgetMusicSnapshot(state: "playing", hasItem: true, title: "Morning Light", artist: "ScriptWidget Sessions", album: "Focus", duration: 224, position: 86, capturedAt: Date(timeIntervalSince1970: 1700000000))
        func isAvailable() -> Bool { available }
        func authorizationStatus() -> String { status }
        func read() throws -> ScriptWidgetMusicSnapshot {
            XCTAssertTrue(Thread.isMainThread)
            reads += 1
            beforeReturn?()
            return snapshot
        }
    }
    private var root: URL!, session: ScriptWidgetLibrarySession!, package: ScriptWidgetPackage!
    private var suite: String!, defaults: UserDefaults!, provider: Provider!
    private let packageName = "Music Playback"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("MusicRuntime-" + UUID().uuidString)
        let container = root.appendingPathComponent("container"), library = root.appendingPathComponent("library")
        for path in [container, library.appendingPathComponent(packageName)] { try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true) }
        try Data("$render(<text>Music</text>);".utf8).write(to: library.appendingPathComponent(packageName).appendingPathComponent("main.jsx"))
        suite = "app.scriptwidget.music-tests." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        session = try .activate(profiles: .init(container: container, legacy: defaults), root: library, isUsingICloud: false)
        package = try XCTUnwrap(session.sourceManager).getScriptPackage(packageName: packageName)
        provider = Provider()
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }
    private func runtime(_ source: String, permissions: [WidgetPackagePermission] = [.music], installed: Bool = true, captured: Bool = true, projection: Bool = false, family: String = "medium") throws -> ScriptWidgetRuntime {
        var manifest = WidgetPackageManifest.newProject(name: packageName)
        manifest.permissions = permissions; manifest.minimumRuntimeVersion = "1.4"
        XCTAssertTrue(package.writeManifest(manifest).0)
        XCTAssertTrue(package.writeFile(relativePath: "main.jsx", content: source).0)
        let snapshot = installed && captured ? try session.capture(name: packageName) : nil
        let sourcePackage = installed ? package! : ScriptWidgetPackage(path: package.path, readonly: true)
        let engine = ScriptWidgetRuntime(package: snapshot?.package ?? sourcePackage, environments: ["widget-size": family, "timeline-is-projection": projection ? "true" : "false"], executionSnapshot: snapshot, isDarkMode: false)
        engine.runningState?.musicProviderForTesting = provider
        return engine
    }
    private func text(_ element: ScriptWidgetRuntimeElement) -> String { (element.getChildren().compactMap { $0 as? String } + element.childrenAsElements().map(text)).joined() }
    private func output(_ engine: ScriptWidgetRuntime, _ source: String) throws -> String {
        let result = engine.executeJSXSyncForWidget(source)
        XCTAssertNil(result.1, result.1?.displayMessage ?? "")
        return text(try XCTUnwrap(result.0))
    }
    private let source = "try{$render(<text>{JSON.stringify(await $music.current())}</text>);}catch(e){$render(<text>{String(e)}</text>);}"
    func testMainThreadSynchronousHostCapturesBeforeWaitingAndReturnsOnlyTypedFields() throws {
        let engine = try runtime(source)
        var value = ""
        let run = { value = (try? self.output(engine, self.source)) ?? "failed" }
        if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
        XCTAssertEqual(object.count, 9); XCTAssertEqual(object["provider"] as? String, "appleMusic")
        XCTAssertEqual(object["title"] as? String, "Morning Light"); XCTAssertEqual(provider.reads, 1)
    }
    func testManagedEntryWithoutPrecapturedSnapshotAlsoPreparesOnMainThread() throws {
        let engine = try runtime(source, captured: false)
        var value = ""
        let run = { value = (try? self.output(engine, self.source)) ?? "failed" }
        if Thread.isMainThread { run() } else { DispatchQueue.main.sync(execute: run) }
        XCTAssertTrue(value.contains("Morning Light"), value); XCTAssertEqual(provider.reads, 1)
    }
    func testBackgroundExecutionDispatchesReadToMainAndReusesOneSnapshot() async throws {
        let code = "const a=await $music.current();a.title='changed';const b=await $music.current();$render(<text>{b.title}</text>);"
        let engine = try runtime(code)
        let done = expectation(description: "Background Music result")
        DispatchQueue.global().async {
            XCTAssertEqual(try? self.output(engine, code), "Morning Light")
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 10)
        XCTAssertEqual(provider.reads, 1)
    }
    func testPermissionAndPresentationChecksDoNotReadThePlayer() throws {
        for engine in [try runtime(source, permissions: []), try runtime(source, installed: false)] {
            XCTAssertTrue(try output(engine, source).contains("music_permission"))
        }
        for engine in [try runtime(source, projection: true), try runtime(source, family: "live-activity")] {
            XCTAssertTrue(try output(engine, source).contains("timeline_read_only"))
        }
        XCTAssertEqual(provider.reads, 0)
    }
    func testDeniedUnavailableAndAuthorizationRevokedDuringRead() throws {
        provider.status = "denied"
        XCTAssertTrue(try output(runtime(source), source).contains("music_permission")); XCTAssertEqual(provider.reads, 0)
        provider.status = "authorized"; provider.available = false
        XCTAssertTrue(try output(runtime(source), source).contains("music_unavailable")); XCTAssertEqual(provider.reads, 0)
        provider.available = true; provider.beforeReturn = { self.provider.status = "denied" }
        XCTAssertTrue(try output(runtime(source), source).contains("music_permission")); XCTAssertEqual(provider.reads, 1)
    }
    func testMetadataCanBeWithheldWhilePlaybackContinuesAndPositionZeroIsValid() throws {
        provider.snapshot = .init(state: "playing", hasItem: false, title: nil, artist: nil, album: nil, duration: nil, position: 0, capturedAt: Date())
        let value = try output(runtime(source), source)
        XCTAssertTrue(value.contains("\"state\":\"playing\"")); XCTAssertTrue(value.contains("\"title\":null")); XCTAssertTrue(value.contains("\"position\":0"))
    }
    func testSharedQueryLimitStillAppliesToCachedMusicReads() throws {
        let code = "try{for(let i=0;i<9;i++)await $music.current();$render(<text>bad</text>);}catch(e){$render(<text>{String(e)}</text>);}"
        XCTAssertTrue(try output(runtime(code), code).contains("query_limit")); XCTAssertEqual(provider.reads, 1)
    }
    func testSnapshotValidationRejectsInvalidStateMetadataAndTimes() throws {
        for snapshot in [
            ScriptWidgetMusicSnapshot(state: "bad", hasItem: false, title: nil, artist: nil, album: nil, duration: nil, position: nil, capturedAt: Date()),
            .init(state: "playing", hasItem: false, title: "Hidden", artist: nil, album: nil, duration: nil, position: nil, capturedAt: Date()),
            .init(state: "playing", hasItem: true, title: String(repeating: "a", count: 513), artist: nil, album: nil, duration: nil, position: nil, capturedAt: Date()),
            .init(state: "playing", hasItem: true, title: "bad\n", artist: nil, album: nil, duration: nil, position: nil, capturedAt: Date()),
            .init(state: "playing", hasItem: true, title: nil, artist: nil, album: nil, duration: 0, position: nil, capturedAt: Date()),
            .init(state: "playing", hasItem: true, title: nil, artist: nil, album: nil, duration: nil, position: -.infinity, capturedAt: Date())
        ] { XCTAssertThrowsError(try snapshot.validate()) }
    }
}

extension MusicRuntimeTests {
    private static var repository: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private static let families = ["small", "medium", "large", "extraLarge", "extraLargePortrait", "accessoryInline", "accessoryCircular", "accessoryRectangular"]
    private static let modes = ["playing", "paused", "stopped", "withheld", "denied", "unavailable"]
    private func configure(_ mode: String) {
        provider.available = mode != "unavailable"
        provider.status = mode == "unavailable" ? "unavailable" : mode == "denied" ? "denied" : "authorized"
        let missing = mode == "withheld" || mode == "stopped"
        provider.snapshot = .init(state: ["paused", "stopped"].contains(mode) ? mode : "playing", hasItem: !missing, title: missing ? nil : "Morning Light", artist: missing ? nil : "ScriptWidget Sessions", album: missing ? nil : "Focus", duration: missing ? nil : 224, position: missing ? nil : 86, capturedAt: Date(timeIntervalSince1970: 1700000000))
    }
    func testMusicTemplateMatchesCanonicalNativeTreesForAllStatesAndFamilies() throws {
        let source = try String(contentsOf: Self.repository.appendingPathComponent("Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Music Playback/main.jsx"), encoding: .utf8)
        var trees: [String: String] = [:]
        for mode in Self.modes {
            configure(mode)
            for family in Self.families {
                try autoreleasepool {
                    let engine = try runtime(source, family: family)
                    let value = engine.executeJSXSyncForWidget(source)
                    XCTAssertNil(value.1, value.1?.displayMessage ?? "")
                    trees[mode + "/" + family] = ScriptWidgetElementTreeJSON.encode(try XCTUnwrap(value.0))
                }
            }
        }
        let output = Self.repository.appendingPathComponent("Web/preview-engine/test/parity/music-playback-trees.json")
        if ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_MUSIC_TREES"] == "1" {
            try JSONSerialization.data(withJSONObject: ["formatVersion": 1, "template": "Music Playback", "trees": trees], options: [.prettyPrinted, .sortedKeys]).write(to: output)
        } else {
            let stored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: output)) as? [String: Any])
            XCTAssertEqual(stored["trees"] as? [String: String], trees)
        }
        XCTAssertEqual(trees.count, 48)
    }
    @MainActor func testMusicTemplateScreenshots() throws {
        guard let path = ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_MUSIC_IMAGES"] else { throw XCTSkip("Opt in to native Music fixture screenshots") }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = try String(contentsOf: Self.repository.appendingPathComponent("Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Music Playback/main.jsx"), encoding: .utf8)
        let sizes: [String: CGSize] = ["small": .init(width:155,height:155), "medium": .init(width:329,height:155), "large": .init(width:329,height:345), "extraLarge": .init(width:715,height:345), "extraLargePortrait": .init(width:345,height:715), "accessoryInline": .init(width:260,height:26), "accessoryCircular": .init(width:72,height:72), "accessoryRectangular": .init(width:172,height:64)]
        for mode in ["playing", "denied", "withheld"] {
            configure(mode)
            for family in mode == "withheld" ? ["medium"] : Self.families {
                try autoreleasepool {
                    let engine = try runtime(source, family: family), value = engine.executeJSXSyncForWidget(source)
                    XCTAssertNil(value.1, value.1?.displayMessage ?? "")
                    let context = ScriptWidgetElementContext(runtime: engine, debugMode: false, scriptName: packageName, scriptParameter: "", package: try XCTUnwrap(engine.runningState).package)
                    let size = sizes[family]!
                    let renderer = ImageRenderer(content: ScriptWidgetElementView(element: try XCTUnwrap(value.0), context: context).frame(width: size.width,height: size.height).background(Color.white).environment(\.colorScheme, .light))
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.cgImage)
                    #if os(macOS)
                    let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png,properties: [:]))
                    #else
                    let png = try XCTUnwrap(UIImage(cgImage: image).pngData())
                    #endif
                    try png.write(to: directory.appendingPathComponent(mode + "-" + family + ".png"))
                }
            }
        }
    }
}
