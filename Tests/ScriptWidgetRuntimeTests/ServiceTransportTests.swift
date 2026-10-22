import Foundation
import XCTest
#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
@testable import ScriptWidget
#endif

final class ServiceTransportTests: XCTestCase {
    private func credential(_ service: ScriptWidgetService = .github) -> ScriptWidgetServiceCredential {
        .init(formatVersion: 1, accountID: UUID(), service: service, revision: UUID(), accessToken: "sample-private-access-token",
            refreshToken: service == .spotify ? "sample-private-refresh-token" : nil,
            oauthClientID: service == .spotify ? "0123456789abcdef" : nil, issuedAt: Date(),
            expiresAt: service == .spotify ? Date().addingTimeInterval(3600) : nil, scopes: service.supportedScopes)
    }
    private func github(_ patch: [String: Any] = [:]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["id": 42, "login": "octocat", "name": "Mona", "public_repos": 3, "followers": 5,
            "email": "private@example.test", "location": "private-place", "private_gists": 8].merging(patch, uniquingKeysWith: { _, new in new }))
    }
    private func decode(_ data: Data, _ operation: ScriptWidgetServiceOperation = .githubProfile, status: Int = 200) throws -> ScriptWidgetServiceResponse {
        try ScriptWidgetServiceResponseDecoder.decode(.init(status: status, body: data), operation: operation, credential: credential(operation.service))
    }
    private func plan(_ credential: ScriptWidgetServiceCredential, operation: ScriptWidgetServiceOperation = .githubProfile) throws -> ScriptWidgetServiceRequestPlan {
        let owner = UUID(), empty = ScriptWidgetServiceAccessPolicy.connected(accountID: credential.accountID, service: credential.service)
        let policy = try empty.updatingGrant(ownerID: owner, operations: [operation], expectedRevision: empty.revision)
        return try .init(operation: operation, credential: credential, policy: policy, ownerID: owner,
            expectedConnectionID: policy.connectionID, isUserInitiatedAction: true, requestID: UUID(), hasNetworkPermission: true, allowsHost: { _ in true })
    }

    @objc func testGitHubProjectionOmitsPrivateFieldsAndPreservesMissingCounts() throws {
        guard case let .profile(value) = try decode(github()) else { return XCTFail("Missing profile") }
        guard case let .profile(managed) = try decode(github(["login":"mona-cat_octo"])) else { return XCTFail("Missing managed profile") }
        XCTAssertEqual(managed.username,"mona-cat_octo")
        XCTAssertEqual(value.subject, "42"); XCTAssertEqual(value.username, "octocat"); XCTAssertEqual(value.publicRepositories, 3)
        XCTAssertNil(value.privateRepositories); XCTAssertNil(value.following)
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        for privateField in ["private@example.test", "private-place", "private_gists", "sample-private-access-token"] { XCTAssertFalse(encoded.contains(privateField)) }
        guard case let .profile(zero) = try decode(github(["total_private_repos": 0])) else { return XCTFail("Missing zero") }
        XCTAssertEqual(zero.privateRepositories, 0)
    }

    @objc func testResponseFieldsCannotEchoCredentialIncludingJSONEscapes() throws {
        for key in ["login", "name"] {
            XCTAssertThrowsError(try decode(github([key: "sample-private-access-token"])))
        }
        let escaped = #"{"id":42,"login":"octocat","public_repos":2,"name":"sample\u002dprivate\u002daccess\u002dtoken"}"#
        XCTAssertThrowsError(try decode(Data(escaped.utf8)))
        let spotify = Data(#"{"id":"safe-id","display_name":"sample-private-refresh-token"}"#.utf8)
        XCTAssertThrowsError(try decode(spotify, .spotifyProfile))
    }

    @objc func testMalformedResponseNumbersStringsAndBodiesFailClosed() throws {
        for patch: [String: Any] in [["id": true], ["id": 0], ["id": 9_007_199_254_740_992], ["public_repos": -1],
            ["public_repos": 1.5], ["public_repos": "3"], ["followers": true], ["login": "bad/user"], ["name": "bad\nname"], ["name": String(repeating: "a", count: 257)]] {
            XCTAssertThrowsError(try decode(github(patch)))
        }
        XCTAssertThrowsError(try decode(Data("[]".utf8)))
        XCTAssertThrowsError(try decode(Data(repeating: 32, count: 131073)))
        XCTAssertThrowsError(try decode(Data()))
        XCTAssertThrowsError(try decode(Data(), status: 204))
    }

    @objc func testSpotifyProjectionAndNoPlaybackHaveExplicitStates() throws {
        guard case let .profile(profile) = try decode(Data(#"{"id":"listener","display_name":"Listener","email":"private@example.test","country":"US"}"#.utf8), .spotifyProfile) else { return XCTFail("Missing profile") }
        XCTAssertEqual(profile.subject, "listener"); XCTAssertNil(profile.followers); XCTAssertNil(profile.privateRepositories)
        XCTAssertEqual(try decode(Data(), .spotifyPlayback, status: 204), .playback(nil))
        XCTAssertThrowsError(try decode(Data(), .spotifyPlayback, status: 200))
        let data = Data(#"{"currently_playing_type":"track","is_playing":false,"progress_ms":0,"device":{"is_active":true,"is_restricted":false},"item":{"id":"track-one","name":"Morning","duration_ms":120000,"artists":[{"name":"Artist"}],"album":{"name":"First"}}}"#.utf8)
        guard case let .playback(value?) = try decode(data, .spotifyPlayback) else { return XCTFail("Missing playback") }
        XCTAssertEqual(value.title, "Morning"); XCTAssertEqual(value.artists, ["Artist"]); XCTAssertEqual(value.album, "First")
        XCTAssertEqual(value.progressMilliseconds, 0); XCTAssertFalse(value.isPlaying); XCTAssertTrue(value.hasActiveDevice); XCTAssertFalse(value.isRestricted)
        let ad = Data(#"{"currently_playing_type":"ad","is_playing":true,"device":null,"item":null}"#.utf8)
        guard case let .playback(unsupported?) = try decode(ad, .spotifyPlayback) else { return XCTFail("Missing unsupported") }
        XCTAssertEqual(unsupported.itemType, "unsupported"); XCTAssertNil(unsupported.title); XCTAssertTrue(unsupported.isRestricted)
    }

    @objc func testHTTPPolicyDeniesRedirectsHTMLLargeBodiesAndSanitizesStatusErrors() throws {
        for status in [301, 302, 307, 308, 400, 404, 500] {
            XCTAssertThrowsError(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: status, contentType: "application/json", expectedBytes: -1))
        }
        for (status, limited, expected): (Int, Bool, ScriptWidgetServiceError) in [(401, false, .expiredAuthorization), (403, false, .permissionDenied), (403, true, .rateLimited), (429, false, .rateLimited)] {
            XCTAssertThrowsError(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: status, contentType: "application/json", expectedBytes: -1, rateLimited: limited)) { XCTAssertEqual($0 as? ScriptWidgetServiceError, expected) }
        }
        XCTAssertThrowsError(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: 200, contentType: "text/html", expectedBytes: 10))
        XCTAssertThrowsError(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: 200, contentType: "application/json", expectedBytes: 131073))
        XCTAssertNoThrow(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: 200, contentType: "Application/JSON; charset=utf-8", expectedBytes: -1))
        XCTAssertNoThrow(try ScriptWidgetServiceResponseDecoder.validateHTTP(status: 204, contentType: nil, expectedBytes: 0))
    }

    private final class PendingTransport: ScriptWidgetServiceHTTPTransport {
        var sent = 0
        var callback: ((Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void)?
        func send(_ request: URLRequest, completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
            sent += 1; callback = completion; return .init({})
        }
    }

    @objc func testReaderRechecksRevocationBeforeSendingAndBeforeDelivering() throws {
        let credential = credential(), transport = PendingTransport(), reader = ScriptWidgetServiceReader(transport: transport)
        let plan = try plan(credential)
        var current = true, received: ScriptWidgetServiceError?, checks = 0
        let validate = { checks += 1; if !current { throw ScriptWidgetServiceError.notConnected } }
        reader.read(plan, credential: credential, revalidate: validate) { if case let .failure(error) = $0 { received = error } }
        XCTAssertEqual(transport.sent, 1); XCTAssertEqual(checks, 1)
        current = false
        transport.callback?(.success(.init(status: 200, body: try github())))
        XCTAssertEqual(received, .notConnected); XCTAssertEqual(checks, 2)
        reader.read(plan, credential: credential, revalidate: validate) { if case let .failure(error) = $0 { received = error } }
        XCTAssertEqual(transport.sent, 1)
        current = true
        reader.read(plan, credential: credential, revalidate: validate) { if case let .failure(error) = $0 { received = error } }
        current = false; transport.callback?(.failure(.unavailable))
        XCTAssertEqual(received, .notConnected)
    }

    @objc func testReaderRefusesWritesEvenWithAValidNativeActionPlan() throws {
        let credential = credential(.spotify), transport = PendingTransport(), reader = ScriptWidgetServiceReader(transport: transport)
        let plan = try plan(credential, operation: .spotifyNext)
        var received: ScriptWidgetServiceError?
        reader.read(plan, credential: credential, revalidate: {}) { if case let .failure(error) = $0 { received = error } }
        XCTAssertEqual(transport.sent, 0); XCTAssertEqual(received, .unsupportedOperation)
    }

    private final class FixtureProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let path = request.url!.path
            let status = path == "/redirect" ? 302 : path == "/unauthorized" ? 401 : 200
            let headers = ["Content-Type": path == "/html" ? "text/html" : "application/json", "Location": "https://example.invalid/leak"]
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            if path == "/redirect" {
                client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: URL(string: "https://example.invalid/leak")!), redirectResponse: response)
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if path == "/large" {
                for _ in 0..<40 { client?.urlProtocol(self, didLoad: Data(repeating: 32, count: 4096)) }
            } else { client?.urlProtocol(self, didLoad: Data(#"{"ok":true}"#.utf8)) }
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    @objc func testActualURLSessionDelegateBoundsStreamingAndRejectsStatusAndMIME() throws {
        let transport = ScriptWidgetServiceURLTransport(protocolClasses: [FixtureProtocol.self])
        for path in ["/ok", "/large", "/redirect", "/unauthorized", "/html"] {
            let done = expectation(description: path)
            var count = 0
            var request = URLRequest(url: URL(string: "https://api.github.com" + path)!); request.httpShouldHandleCookies = false
            let handle = transport.send(request) { result in
                count += 1
                if path == "/ok" { XCTAssertEqual(try? result.get().status, 200) }
                else { if case .success = result { XCTFail("Unexpected success for \(path)") } }
                done.fulfill()
            }
            wait(for: [done], timeout: 3)
            XCTAssertEqual(count, 1)
            withExtendedLifetime(handle) {}
        }
    }

    private final class Memory: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        var failed = false
        var failWrites = false
        func read(_ account: String) throws -> Data? { if failed { throw ScriptWidgetServiceError.locked }; return values[account] }
        func write(_ data: Data, account: String) throws { if failed || failWrites { throw ScriptWidgetServiceError.storageUnavailable }; values[account] = data }
        func remove(_ account: String) throws { if failed || failWrites { throw ScriptWidgetServiceError.storageUnavailable }; values.removeValue(forKey: account) }
    }
    private func connections(_ memory: Memory) -> ScriptWidgetServiceConnections {
        let lock = NSLock()
        return .init(keychain: memory, coordinate: { action in lock.lock(); defer { lock.unlock() }; try action() })
    }
    private func profile() -> ScriptWidgetServiceProfile {
        .init(service: .github, subject: "42", username: "octocat", displayName: "Mona", publicRepositories: 3, privateRepositories: nil, followers: 5, following: nil)
    }

    @objc func testConnectionEnvelopeBindsCredentialPolicyAndRejectsMalformedRecords() throws {
        let connection = try ScriptWidgetServiceConnection(credential: credential(), profile: profile()), bytes = try connection.encoded()
        XCTAssertEqual(try ScriptWidgetServiceConnection.decode(bytes, service: .github).revision, connection.revision)
        let base = try JSONSerialization.jsonObject(with: bytes) as! [String: Any]
        for patch: [String: Any] in [["formatVersion": true], ["formatVersion": 2], ["unknown": "value"], ["subject": ""], ["label": "sample-private-access-token"]] {
            XCTAssertThrowsError(try ScriptWidgetServiceConnection.decode(JSONSerialization.data(withJSONObject: base.merging(patch, uniquingKeysWith: { _, new in new })), service: .github))
        }
        var different = base, policy = base["policy"] as! [String: Any]
        policy["accountID"] = UUID().uuidString; different["policy"] = policy
        XCTAssertThrowsError(try ScriptWidgetServiceConnection.decode(JSONSerialization.data(withJSONObject: different), service: .github))
        XCTAssertThrowsError(try ScriptWidgetServiceConnection.decode(bytes, service: .spotify))
        XCTAssertFalse(String(reflecting: connection).contains("sample-private"))
    }

    @objc func testConnectionMutationsConflictAndReconnectionDoesNotInheritGrants() throws {
        let memory = Memory(), store = connections(memory), first = try store.connect(credential(), verifiedProfile: profile(), expectedRevision: nil)
        let owner = UUID(), granted = try store.setGrant(service: .github, ownerID: owner, operations: [.githubProfile], expectedRevision: first.revision)
        XCTAssertThrowsError(try store.revalidate(first)); XCTAssertNoThrow(try store.revalidate(granted))
        XCTAssertThrowsError(try store.disconnect(.github, expectedRevision: first.revision))
        XCTAssertThrowsError(try store.connect(credential(), verifiedProfile: profile(), expectedRevision: nil))
        XCTAssertThrowsError(try store.setGrant(service: .github, ownerID: owner, operations: [], expectedRevision: first.revision))
        try store.disconnect(.github, expectedRevision: granted.revision)
        XCTAssertThrowsError(try store.revalidate(granted)); XCTAssertNil(try store.connection(.github))
        let reconnected = try store.connect(credential(), verifiedProfile: profile(), expectedRevision: nil)
        XCTAssertNotEqual(reconnected.credential.accountID, first.credential.accountID); XCTAssertTrue(reconnected.policy.grants.isEmpty)
        XCTAssertThrowsError(try store.revalidate(granted))
    }

    @objc func testLockedOrCorruptConnectionNeverAppearsDisconnected() throws {
        let memory = Memory(), store = connections(memory)
        memory.failed = true
        XCTAssertThrowsError(try store.connection(.github)) { XCTAssertEqual($0 as? ScriptWidgetServiceError, .locked) }
        memory.failed = false; memory.values["connection:github"] = Data("{}".utf8)
        XCTAssertThrowsError(try store.connection(.github))
        XCTAssertThrowsError(try store.connect(credential(), verifiedProfile: profile(), expectedRevision: nil))
    }

    @objc func testConcurrentConnectionsHaveOneWinnerAndFailedUpdatesPreserveTheSavedRecord() throws {
        let memory = Memory(), store = connections(memory), resultsLock = NSLock()
        var successes = 0, failures = 0
        DispatchQueue.concurrentPerform(iterations: 16) { _ in
            do {
                _ = try store.connect(credential(), verifiedProfile: profile(), expectedRevision: nil)
                resultsLock.lock(); successes += 1; resultsLock.unlock()
            } catch {
                resultsLock.lock(); failures += 1; resultsLock.unlock()
                XCTAssertEqual(error as? ScriptWidgetServiceError, .conflict)
            }
        }
        XCTAssertEqual(successes, 1); XCTAssertEqual(failures, 15)
        let saved = try XCTUnwrap(store.connection(.github)), bytes = memory.values
        memory.failWrites = true
        XCTAssertThrowsError(try store.setGrant(service: .github, ownerID: UUID(), operations: [.githubProfile], expectedRevision: saved.revision))
        XCTAssertThrowsError(try store.disconnect(.github, expectedRevision: saved.revision))
        memory.failWrites = false
        XCTAssertEqual(memory.values, bytes); XCTAssertEqual(try store.connection(.github)?.revision, saved.revision)
    }

    @objc func testRequestCancellationHandleIsIdempotent() {
        let lock = NSLock(); var calls = 0
        let handle = ScriptWidgetServiceRequestHandle { lock.lock(); calls += 1; lock.unlock() }
        DispatchQueue.concurrentPerform(iterations: 32) { _ in handle.cancel() }
        XCTAssertEqual(calls, 1); XCTAssertFalse(String(reflecting: handle).contains("sample-private"))
    }
}

#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
import SwiftUI
import Combine
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class ServiceAccountsViewTests: XCTestCase {
    private final class Memory: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        var fail = false
        func read(_ account: String) throws -> Data? { if fail { throw ScriptWidgetServiceError.locked }; return values[account] }
        func write(_ data: Data, account: String) throws { values[account] = data }
        func remove(_ account: String) throws { values.removeValue(forKey: account) }
    }
    private final class Pending: ScriptWidgetServiceHTTPTransport {
        var callback: ((Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void)?
        var cancelled = false
        func send(_ request: URLRequest, completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
            callback = completion; return .init { self.cancelled = true }
        }
    }
    private func store(_ memory: Memory) -> ScriptWidgetServiceConnections {
        let lock = NSLock()
        return .init(keychain: memory, coordinate: { action in lock.lock(); defer { lock.unlock() }; try action() })
    }
    private let profileResponse = ScriptWidgetServiceHTTPResponse(status: 200, body: Data(#"{"id":42,"login":"octocat","public_repos":3,"followers":5}"#.utf8))

    func testConnectionUIControllerVerifiesThenSavesAndGrantsOnlyTheSelectedOwner() async throws {
        let memory = Memory(), store = store(memory), transport = Pending(), ownerID = UUID()
        let owner = ScriptWidgetServiceAccountsModel.Owner(id: ownerID, name: "GitHub Profile", validate: {})
        let model = ScriptWidgetServiceAccountsModel(store: store, reader: .init(transport: transport), loadOwners: { [owner] })
        model.reload(); XCTAssertTrue(model.ready); XCTAssertNil(model.connection)
        model.connectGitHub(token: "sample-private-access-token")
        XCTAssertTrue(model.busy); XCTAssertTrue(memory.values.isEmpty)
        let done = expectation(description: "Verified connection saved")
        let observation = model.$busy.dropFirst().filter { !$0 }.sink { _ in done.fulfill() }
        transport.callback?(.success(profileResponse))
        await fulfillment(of: [done], timeout: 3)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(model.connection?.label, "octocat"); XCTAssertNil(model.message)
        XCTAssertEqual(memory.values.count, 1); XCTAssertTrue(model.connection!.grantedOwners.isEmpty)
        model.setGranted(true, owner: owner)
        XCTAssertEqual(model.connection?.grantedOwners, [ownerID])
        model.setGranted(false, owner: owner)
        XCTAssertTrue(model.connection!.grantedOwners.isEmpty)
        model.disconnect(); XCTAssertNil(model.connection); XCTAssertTrue(memory.values.isEmpty)
    }

    func testLeavingTheScreenOrCancellingCannotSaveAnInFlightToken() async throws {
        let memory = Memory(), transport = Pending(), model = ScriptWidgetServiceAccountsModel(store: store(memory), reader: .init(transport: transport), loadOwners: { [] })
        model.reload(); model.connectGitHub(token: "sample-private-access-token"); model.cancel()
        transport.callback?(.success(profileResponse))
        let drained = expectation(description: "Main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 3)
        XCTAssertTrue(transport.cancelled); XCTAssertFalse(model.busy); XCTAssertNil(model.connection); XCTAssertTrue(memory.values.isEmpty)
    }

    func testUIControllerRejectsRetiredOwnersAndReloadsStaleGrantDrafts() async throws {
        let memory = Memory(), store = store(memory), transport = Pending()
        let retired = ScriptWidgetServiceAccountsModel.Owner(id: UUID(), name: "Old Widget", validate: { throw ScriptWidgetServiceError.conflict })
        let model = ScriptWidgetServiceAccountsModel(store: store, reader: .init(transport: transport), loadOwners: { [retired] })
        model.reload(); model.connectGitHub(token: "sample-private-access-token")
        let done = expectation(description: "Connection saved")
        let observation = model.$busy.dropFirst().filter { !$0 }.sink { _ in done.fulfill() }
        transport.callback?(.success(profileResponse)); await fulfillment(of: [done], timeout: 3)
        withExtendedLifetime(observation) {}
        model.setGranted(true, owner: retired)
        XCTAssertTrue(model.connection!.grantedOwners.isEmpty); XCTAssertEqual(model.message, ScriptWidgetServiceError.conflict.localizedDescription)
        let current = try XCTUnwrap(store.connection(.github))
        _ = try store.setGrant(service: .github, ownerID: UUID(), operations: [.githubProfile], expectedRevision: current.revision)
        model.disconnect(); XCTAssertNotNil(model.connection)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.conflict.localizedDescription)
        model.reload(); XCTAssertNil(model.message); XCTAssertNotEqual(model.connection?.revision, current.revision)
    }

    func testAConnectionChangedWhileVerifyingCannotBeOverwrittenByAnOldScreen() async throws {
        let memory = Memory(), store = store(memory), transport = Pending()
        let model = ScriptWidgetServiceAccountsModel(store: store, reader: .init(transport: transport), loadOwners: { [] })
        model.reload(); model.connectGitHub(token: "sample-pending-token")
        let other = ScriptWidgetServiceCredential(formatVersion: 1, accountID: UUID(), service: .github, revision: UUID(), accessToken: "sample-other-token", refreshToken: nil, oauthClientID: nil, issuedAt: Date(), expiresAt: nil, scopes: [])
        let profile = ScriptWidgetServiceProfile(service: .github, subject: "43", username: "second-user", displayName: nil, publicRepositories: 0, privateRepositories: nil, followers: nil, following: nil)
        let winner = try store.connect(other, verifiedProfile: profile, expectedRevision: nil)
        let done = expectation(description: "Stale connection rejected")
        let observation = model.$busy.dropFirst().filter { !$0 }.sink { _ in done.fulfill() }
        transport.callback?(.success(profileResponse)); await fulfillment(of: [done], timeout: 3)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(model.message, ScriptWidgetServiceError.conflict.localizedDescription)
        XCTAssertEqual(try store.connection(.github)?.revision, winner.revision)
        model.reload(); XCTAssertEqual(model.connection?.label, "second-user")
    }

    func testServiceAccountsScreenshots() async throws {
        guard let path = ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_SERVICE_ACCOUNTS"] else {
            throw XCTSkip("Set SCRIPTWIDGET_EXPORT_SERVICE_ACCOUNTS for native account settings screenshots")
        }
        #if os(macOS)
        let platform = "macos"
        #else
        let platform = "ios"
        #endif
        let directory = URL(fileURLWithPath: path).appendingPathComponent(platform)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for state in ["disconnected", "connected", "locked"] {
            let memory = Memory(), store = store(memory)
            let ownerID = UUID(), owner = ScriptWidgetServiceAccountsModel.Owner(id: ownerID, name: "GitHub Profile", validate: {})
            if state == "connected" {
                let credential = ScriptWidgetServiceCredential(formatVersion: 1, accountID: UUID(), service: .github, revision: UUID(), accessToken: "sample-private-access-token", refreshToken: nil, oauthClientID: nil, issuedAt: Date(), expiresAt: nil, scopes: [])
                let profile = ScriptWidgetServiceProfile(service: .github, subject: "42", username: "octocat", displayName: "Mona", publicRepositories: 3, privateRepositories: nil, followers: 5, following: nil)
                let saved = try store.connect(credential, verifiedProfile: profile, expectedRevision: nil)
                _ = try store.setGrant(service: .github, ownerID: ownerID, operations: [.githubProfile], expectedRevision: saved.revision)
            }
            memory.fail = state == "locked"
            let model = ScriptWidgetServiceAccountsModel(store: store, loadOwners: { [owner] }); model.reload()
            let content = NavigationStack { ScriptWidgetServiceAccountsView(model: model) }.environment(\.colorScheme, .light)
            #if os(macOS)
            let host = NSHostingView(rootView: content.background(Color.white)); host.frame = NSRect(x: 0, y: 0, width: 620, height: 780)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua); window.contentView = host
            window.orderFront(nil); host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            defer { window.orderOut(nil) }
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            defer { window.isHidden = true; previous?.makeKey() }
            let controller = UIHostingController(rootView: content)
            window.overrideUserInterfaceStyle = .light; window.rootViewController = controller
            window.makeKeyAndVisible(); controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 150_000_000)
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            XCTAssertGreaterThan(Set(pixels as Data).count, 8, "Account settings must render content, not a blank canvas")
            let png = try XCTUnwrap(image.pngData())
            #endif
            try png.write(to: directory.appendingPathComponent(state + ".png"))
        }
    }
}
#endif
