import Foundation
import XCTest
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import ScriptWidget

final class ServicesRuntimeTests: XCTestCase {
    private final class Memory: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        var error: ScriptWidgetServiceError?
        func read(_ key: String) throws -> Data? { if let error { throw error }; return values[key] }
        func write(_ data: Data, account: String) throws { values[account] = data }
        func remove(_ account: String) throws { values.removeValue(forKey: account) }
    }
    private final class Transport: ScriptWidgetServiceHTTPTransport {
        var calls = 0
        var beforeReply: (() throws -> Void)?
        var result: Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError> = .success(.init(status: 200, body: Data(#"{"id":42,"login":"octocat","name":"Mona","public_repos":32,"total_private_repos":8,"followers":128,"following":24,"email":"private@example.test"}"#.utf8)))
        func send(_ request: URLRequest, completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
            calls += 1
            do { try beforeReply?(); completion(result) } catch { completion(.failure(error as? ScriptWidgetServiceError ?? .unavailable)) }
            return .init({})
        }
    }
    private var root: URL!, container: URL!, session: ScriptWidgetLibrarySession!, package: ScriptWidgetPackage!
    private var suite: String!, defaults: UserDefaults!, memory: Memory!, store: ScriptWidgetServiceConnections!, transport: Transport!
    private var owner: UUID!
    private let packageName = "GitHub Profile"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ServicesRuntime-" + UUID().uuidString)
        container = root.appendingPathComponent("container"); let library = root.appendingPathComponent("library")
        for path in [container!, library.appendingPathComponent(packageName)] { try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true) }
        try Data("$render(<text>Profile</text>);".utf8).write(to: library.appendingPathComponent(packageName).appendingPathComponent("main.jsx"))
        suite = "app.scriptwidget.service-tests." + UUID().uuidString
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        session = try .activate(profiles: .init(container: container, legacy: defaults), root: library, isUsingICloud: false)
        package = try XCTUnwrap(session.sourceManager).getScriptPackage(packageName: packageName)
        owner = try UUID(uuidString: XCTUnwrap(package.managedScope).context.boundDirectory(name: packageName, role: .source).ownerID)
        memory = Memory(); let lock = NSLock()
        store = .init(keychain: memory, coordinate: { action in lock.lock(); defer { lock.unlock() }; try action() })
        transport = Transport()
    }
    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }
    private func connect(granted: Bool = true) throws {
        let credential = ScriptWidgetServiceCredential(formatVersion: 1, accountID: UUID(), service: .github, revision: UUID(), accessToken: "private-fixture-access-token", refreshToken: nil, oauthClientID: nil, issuedAt: Date(), expiresAt: nil, scopes: [])
        let profile = ScriptWidgetServiceProfile(service: .github, subject: "42", username: "octocat", displayName: "Mona", publicRepositories: 32, privateRepositories: 8, followers: 128, following: 24)
        let connection = try store.connect(credential, verifiedProfile: profile, expectedRevision: nil)
        if granted { _ = try store.setGrant(service: .github, ownerID: owner, operations: [.githubProfile], expectedRevision: connection.revision) }
    }
    private func runtime(_ source: String, permissions: [WidgetPackagePermission] = [.services,.network], domains: [String] = ["api.github.com"], family: String = "medium", projection: Bool = false, installed: Bool = true) throws -> ScriptWidgetRuntime {
        var manifest = WidgetPackageManifest.newProject(name: packageName); manifest.permissions = permissions; manifest.networkDomains = domains; manifest.minimumRuntimeVersion = "1.4"
        XCTAssertTrue(package.writeManifest(manifest).0); XCTAssertTrue(package.writeFile(relativePath: "main.jsx", content: source).0)
        let snapshot = installed ? try session.capture(name: packageName) : nil
        let runtime = ScriptWidgetRuntime(package: snapshot?.package ?? ScriptWidgetPackage(path: package.path, readonly: true), environments: ["widget-size":family,"timeline-is-projection":projection ? "true":"false"], executionSnapshot: snapshot, isDarkMode: false)
        runtime.runningState?.serviceConnectionsForTesting = store; runtime.runningState?.serviceReaderForTesting = .init(transport: transport)
        return runtime
    }
    private func text(_ element: ScriptWidgetRuntimeElement) -> String { (element.getChildren().compactMap { $0 as? String } + element.childrenAsElements().map(text)).joined() }
    private func result(_ source: String, permissions: [WidgetPackagePermission] = [.services,.network], domains: [String] = ["api.github.com"], projection: Bool = false, installed: Bool = true, family: String = "medium") throws -> String {
        let value = try runtime(source, permissions: permissions, domains: domains, family: family, projection: projection, installed: installed).executeJSXSyncForWidget(source)
        XCTAssertNil(value.1, value.1?.displayMessage ?? "")
        return text(try XCTUnwrap(value.0))
    }
    private let profileSource = "try{const p=await $services.profile('github');$render(<text>{JSON.stringify(p)}</text>);}catch(e){$render(<text>{String(e)}</text>);}"
    private let statusSource = "try{$render(<text>{await $services.status('github')}</text>);}catch(e){$render(<text>{String(e)}</text>);}"

    func testInstalledOwnerReadsOnlyTypedProfileFieldsAndUnsharedCountsRemainNull() throws {
        try connect()
        let response = try result(profileSource)
        let value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String:Any])
        XCTAssertEqual(value["publicRepositories"] as? Int, 32); XCTAssertEqual(value["privateRepositories"] as? Int, 8)
        XCTAssertEqual(value["subject"] as? String, "42"); XCTAssertEqual(value.count, 8)
        XCTAssertFalse(response.contains("private-fixture-access-token")); XCTAssertFalse(response.contains("private@example.test"))
        transport.result = .success(.init(status: 200, body: Data(#"{"id":42,"login":"octocat","public_repos":0}"#.utf8)))
        let nullable = try result(profileSource)
        XCTAssertTrue(nullable.contains("\"privateRepositories\":null")); XCTAssertTrue(nullable.contains("\"publicRepositories\":0"))
    }
    func testStatusDistinguishesDisconnectedAndUngrantableAccountsWithoutNetworkCalls() throws {
        XCTAssertEqual(try result(statusSource), "notConnected")
        try connect(granted: false)
        XCTAssertEqual(try result(statusSource), "notGranted")
        XCTAssertTrue(try result(profileSource).contains("service_permission"))
        let connection = try XCTUnwrap(store.connection(.github))
        _ = try store.setGrant(service: .github, ownerID: owner, operations: [.githubProfile], expectedRevision: connection.revision)
        XCTAssertEqual(try result(statusSource), "connected"); XCTAssertEqual(transport.calls, 0)
    }
    func testManifestDomainsAndInstalledIdentityCannotBeBypassed() throws {
        try connect()
        for permissions: [WidgetPackagePermission] in [[], [.network], [.services]] {
            let denied = try result(profileSource, permissions: permissions, domains: permissions.contains(.network) ? ["api.github.com"] : [])
            XCTAssertTrue(denied.contains("service_permission"), denied)
        }
        for domains in [["api.github.com.attacker.test"], ["github.com"]] {
            let denied = try result(profileSource, domains: domains)
            XCTAssertTrue(denied.contains("service_permission"), denied)
        }
        XCTAssertTrue(try result(profileSource, installed: false).contains("service_permission"))
        XCTAssertEqual(transport.calls, 0)
        XCTAssertEqual(try result(statusSource, permissions: [.services], domains: []), "connected")
    }
    func testUnsupportedProviderAndFuturePresentationsCannotMakeRequests() throws {
        try connect()
        XCTAssertEqual(try result("$render(<text>{typeof $services.playback}</text>);"), "undefined")
        for service in ["spotify", "removed-provider", "https://attacker.test", "unknown"] {
            for method in ["status", "profile"] {
                let source = "try{await $services.\(method)('\(service)');$render(<text>bad</text>);}catch(e){$render(<text>{String(e)}</text>);}"
                XCTAssertTrue(try result(source).contains("service_operation"))
            }
        }
        XCTAssertTrue(try result(profileSource, projection: true).contains("timeline_read_only"))
        XCTAssertTrue(try result(profileSource, family: "live-activity").contains("timeline_read_only"))
        XCTAssertEqual(transport.calls, 0)
    }
    func testKeychainErrorsDoNotPretendThatTheAccountWasDisconnected() throws {
        memory.error = .locked
        XCTAssertTrue(try result(statusSource).contains("service_locked"))
        memory.error = .invalidCredential
        XCTAssertTrue(try result(statusSource).contains("service_credential"))
        memory.error = .invalidConfiguration
        XCTAssertEqual(try result(statusSource), "unavailable")
        XCTAssertEqual(transport.calls, 0)
    }
    func testSharedDataAndNetworkBudgetsAlsoApplyToAuthenticatedReads() throws {
        try connect()
        let source = "try{for(let i=0;i<9;i++)await $services.profile('github');$render(<text>bad</text>);}catch(e){$render(<text>{String(e)}</text>);}"
        XCTAssertTrue(try result(source).contains("query_limit")); XCTAssertEqual(transport.calls, 8)
        let engine = try runtime(profileSource), state = try XCTUnwrap(engine.runningState)
        for _ in 0..<8 { XCTAssertTrue(state.executionSession.register(URLSession.shared.dataTask(with: URL(string:"https://example.invalid")!))) }
        let output = engine.executeJSXSyncForWidget(profileSource)
        XCTAssertNil(output.1); XCTAssertTrue(text(try XCTUnwrap(output.0)).contains("network_limit")); XCTAssertEqual(transport.calls, 8)
    }
    func testDisconnectDuringRequestAndChangedProviderSubjectCannotDeliverAProfile() throws {
        try connect()
        transport.beforeReply = {
            let connection = try XCTUnwrap(self.store.connection(.github))
            try self.store.disconnect(.github, expectedRevision: connection.revision)
        }
        XCTAssertTrue(try result(profileSource).contains("service_not_connected"))
        transport.beforeReply = nil; try connect()
        transport.result = .success(.init(status:200, body:Data(#"{"id":43,"login":"another-user","public_repos":999}"#.utf8)))
        let rejected = try result(profileSource)
        XCTAssertTrue(rejected.contains("service_credential")); XCTAssertFalse(rejected.contains("another-user"))
    }
    func testNativeFetchAndServiceReservationsShareConcurrencyAndTotalLimits() {
        let session = ScriptWidgetExecutionSession(), url = URL(string:"https://example.invalid")!
        let task = URLSession.shared.dataTask(with:url)
        XCTAssertTrue(session.register(task))
        let ids = (0..<7).compactMap { _ in session.registerServiceNetworkRequest() }
        XCTAssertEqual(ids.count, 7); XCTAssertNil(session.registerServiceNetworkRequest())
        XCTAssertFalse(session.register(URLSession.shared.dataTask(with:url)))
        for id in ids { session.completeServiceNetworkRequest(id) }; session.complete(task)
        for _ in 8..<32 { let id = session.registerServiceNetworkRequest(); XCTAssertNotNil(id); if let id { session.completeServiceNetworkRequest(id) } }
        XCTAssertNil(session.registerServiceNetworkRequest()); XCTAssertEqual(session.totalNetworkRequests, 32)
        session.finish(); XCTAssertNil(session.registerServiceNetworkRequest())
    }
}

extension ServicesRuntimeTests {
    private static var repository: URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private static let families = ["small","medium","large","extraLarge","extraLargePortrait","accessoryInline","accessoryCircular","accessoryRectangular"]
    private static let modes = ["connected","notConnected","notGranted","empty","publicOnly","expired","rateLimited","offline","unavailable"]
    private func configure(_ mode: String) throws {
        memory.error = nil; transport.beforeReply = nil
        if let current = try store.connection(.github) { try store.disconnect(.github, expectedRevision: current.revision) }
        if mode != "notConnected" { try connect(granted: mode != "notGranted") }
        let body: [String:Any] = ["id":42,"login":"octocat","name":"Mona","public_repos":mode == "empty" ? 0:32,"followers":mode == "empty" ? 0:128,"following":mode == "empty" ? 0:24]
        var data = body
        if mode != "publicOnly" { data["total_private_repos"] = mode == "empty" ? 0:8 }
        transport.result = .success(.init(status:200,body:try JSONSerialization.data(withJSONObject:data)))
        if mode == "expired" { transport.result = .failure(.expiredAuthorization) }
        if mode == "rateLimited" { transport.result = .failure(.rateLimited) }
        if mode == "offline" { transport.result = .failure(.unavailable) }
        if mode == "unavailable" { memory.error = .invalidConfiguration }
    }
    func testGitHubTemplateMatchesNativeCanonicalTreesForAllStatesAndFamilies() throws {
        let template = Self.repository.appendingPathComponent("Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/GitHub Profile/main.jsx")
        let source = try String(contentsOf: template, encoding:.utf8)
        var trees: [String:String] = [:]
        for mode in Self.modes {
            try configure(mode)
            for family in Self.families {
                try autoreleasepool {
                    let engine = try runtime(source,family:family)
                    let value = engine.executeJSXSyncForWidget(source)
                    XCTAssertNil(value.1,value.1?.displayMessage ?? "")
                    trees[mode+"/"+family] = ScriptWidgetElementTreeJSON.encode(try XCTUnwrap(value.0))
                }
            }
        }
        let output = Self.repository.appendingPathComponent("Web/preview-engine/test/parity/github-profile-trees.json")
        if ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_GITHUB_PROFILE_TREES"] == "1" {
            try JSONSerialization.data(withJSONObject:["formatVersion":1,"template":"GitHub Profile","trees":trees],options:[.prettyPrinted,.sortedKeys]).write(to:output)
        } else {
            let stored = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:output)) as? [String:Any])
            XCTAssertEqual(stored["trees"] as? [String:String],trees)
        }
        XCTAssertEqual(trees.count,72)
    }
    @MainActor func testGitHubTemplateScreenshots() throws {
        guard let path = ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_GITHUB_PROFILE"] else { throw XCTSkip("Set SCRIPTWIDGET_EXPORT_GITHUB_PROFILE for native service template captures") }
        let directory = URL(fileURLWithPath:path); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let source = try String(contentsOf:Self.repository.appendingPathComponent("Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/GitHub Profile/main.jsx"),encoding:.utf8)
        let sizes: [String:CGSize] = ["small":.init(width:155,height:155),"medium":.init(width:329,height:155),"large":.init(width:329,height:345),"extraLarge":.init(width:715,height:345),"extraLargePortrait":.init(width:345,height:715),"accessoryInline":.init(width:260,height:26),"accessoryCircular":.init(width:72,height:72),"accessoryRectangular":.init(width:172,height:64)]
        for mode in ["connected","notConnected","publicOnly"] {
            try configure(mode)
            for family in mode == "publicOnly" ? ["medium"] : Self.families {
                try autoreleasepool {
                    let engine = try runtime(source,family:family), value = engine.executeJSXSyncForWidget(source)
                    XCTAssertNil(value.1,value.1?.displayMessage ?? "")
                    let context = ScriptWidgetElementContext(runtime:engine,debugMode:false,scriptName:packageName,scriptParameter:"",package:try XCTUnwrap(engine.runningState).package)
                    let size = sizes[family]!
                    let renderer = ImageRenderer(content:ScriptWidgetElementView(element:try XCTUnwrap(value.0),context:context).frame(width:size.width,height:size.height).background(Color.white).environment(\.colorScheme,.light))
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.cgImage)
                    #if os(macOS)
                    let png = try XCTUnwrap(NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:]))
                    #else
                    let png = try XCTUnwrap(UIImage(cgImage:image).pngData())
                    #endif
                    try png.write(to:directory.appendingPathComponent(mode+"-"+family+".png"))
                }
            }
        }
    }
}
