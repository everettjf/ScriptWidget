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
        for name: String? in [nil, "", "   "] {
            let profile = ScriptWidgetServiceProfile(service: .spotify, subject: "sample-user", username: nil, displayName: name, publicRepositories: nil, privateRepositories: nil, followers: nil, following: nil)
            XCTAssertEqual(try ScriptWidgetServiceConnection(credential: credential(.spotify), profile: profile).label, "sample-user")
        }
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

    @objc func testCredentialRefreshPreservesGrantsAndRejectsStaleRotationOrDisconnect() throws {
        let memory = Memory(), store = connections(memory), original = credential(.spotify)
        let profile = ScriptWidgetServiceProfile(service: .spotify, subject: "sample-user", username: nil, displayName: "Sample listener", publicRepositories: nil, privateRepositories: nil, followers: nil, following: nil)
        let connected = try store.connect(original, verifiedProfile: profile, expectedRevision: nil)
        let granted = try store.setGrant(service: .spotify, ownerID: UUID(), operations: [.spotifyProfile], expectedRevision: connected.revision)
        let updated = ScriptWidgetServiceCredential(formatVersion: 1, accountID: original.accountID, service: .spotify, revision: UUID(), accessToken: "rotated-sample-access", refreshToken: "rotated-sample-refresh", oauthClientID: original.oauthClientID, issuedAt: original.issuedAt.addingTimeInterval(60), expiresAt: original.issuedAt.addingTimeInterval(3660), scopes: original.scopes)
        XCTAssertThrowsError(try store.refreshCredential(updated, expected: connected), "A concurrent grant change invalidates the pending refresh")
        let rotated = try store.refreshCredential(updated, expected: granted)
        XCTAssertEqual(rotated.policy.formatVersion, granted.policy.formatVersion)
        XCTAssertEqual(rotated.policy.accountID, granted.policy.accountID)
        XCTAssertEqual(rotated.policy.service, granted.policy.service)
        XCTAssertEqual(rotated.policy.connectionID, granted.policy.connectionID)
        XCTAssertEqual(rotated.policy.revision, granted.policy.revision)
        XCTAssertEqual(rotated.policy.active, granted.policy.active)
        XCTAssertEqual(rotated.policy.grants.map(\.ownerID), granted.policy.grants.map(\.ownerID))
        XCTAssertEqual(rotated.policy.grants.map(\.operations), granted.policy.grants.map(\.operations))
        XCTAssertEqual(rotated.subject, granted.subject); XCTAssertEqual(rotated.label, granted.label)
        XCTAssertEqual(rotated.credential.revision, updated.revision)
        XCTAssertThrowsError(try store.revalidate(granted)); XCTAssertNoThrow(try store.revalidate(rotated))
        XCTAssertThrowsError(try store.refreshCredential(updated, expected: granted))
        try store.disconnect(.spotify, expectedRevision: rotated.revision)
        XCTAssertThrowsError(try store.refreshCredential(updated, expected: rotated))
        XCTAssertNil(try store.connection(.spotify))
    }

    @objc func testCredentialRefreshCannotSwitchAccountClientScopesOrLoseSavedStateOnWriteFailure() throws {
        let memory = Memory(), store = connections(memory), original = credential(.spotify)
        let profile = ScriptWidgetServiceProfile(service: .spotify, subject: "sample-user", username: nil, displayName: "Sample listener", publicRepositories: nil, privateRepositories: nil, followers: nil, following: nil)
        let connected = try store.connect(original, verifiedProfile: profile, expectedRevision: nil)
        func update(account: UUID? = nil, client: String? = nil, scopes: Set<String>? = nil, revision: UUID = UUID(), issuedAt: Date? = nil) -> ScriptWidgetServiceCredential {
            .init(formatVersion: 1, accountID: account ?? original.accountID, service: .spotify, revision: revision, accessToken: "rotated-sample-access", refreshToken: "rotated-sample-refresh", oauthClientID: client ?? original.oauthClientID, issuedAt: issuedAt ?? original.issuedAt.addingTimeInterval(60), expiresAt: original.issuedAt.addingTimeInterval(3600), scopes: scopes ?? original.scopes)
        }
        let before = memory.values
        for invalid in [update(account: UUID()), update(client: "different-client-id"), update(scopes: original.scopes.subtracting(["user-modify-playback-state"])), update(revision: original.revision), update(issuedAt: original.issuedAt.addingTimeInterval(-1))] {
            XCTAssertThrowsError(try store.refreshCredential(invalid, expected: connected))
            XCTAssertEqual(memory.values, before)
        }
        memory.failWrites = true
        XCTAssertThrowsError(try store.refreshCredential(update(), expected: connected))
        memory.failWrites = false
        XCTAssertEqual(memory.values, before); XCTAssertNoThrow(try store.revalidate(connected))
    }

    @objc func testTokenResponseBudgetRejectsChunkedDataBeforeTheGeneralAPILimit() throws {
        let transport = ScriptWidgetServiceURLTransport(protocolClasses: [FixtureProtocol.self], maximumResponseBytes: 16 * 1024)
        let done = expectation(description: "Token streaming budget")
        let handle = transport.send(URLRequest(url: URL(string: "https://accounts.spotify.com/large")!)) { result in
            if case .success = result { XCTFail("Oversized token response was accepted") }; done.fulfill()
        }
        wait(for: [done], timeout: 3); withExtendedLifetime(handle) {}
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
            let spotify = ScriptWidgetSpotifyAccountsModel(clientID: nil, store: store, loadOwners: { [] })
            let content = NavigationStack { ScriptWidgetServiceAccountsView(model: model, spotifyModel: spotify) }.environment(\.colorScheme, .light)
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

#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
import AuthenticationServices

@MainActor
final class SpotifyAccountsFlowTests: XCTestCase {
    private let clientID = "0123456789abcdef0123456789abcdef"
    private final class Memory: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        func read(_ account: String) throws -> Data? { values[account] }
        func write(_ data: Data, account: String) throws { values[account] = data }
        func remove(_ account: String) throws { values.removeValue(forKey: account) }
    }
    private final class HTTP: ScriptWidgetServiceHTTPTransport {
        var requests: [URLRequest] = []
        var callbacks: [(Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void] = []
        var cancelled = false
        func send(_ request: URLRequest, completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
            requests.append(request); callbacks.append(completion)
            return .init { self.cancelled = true }
        }
    }
    private final class Browser: ScriptWidgetSpotifyWebAuthorizing {
        var authorization: ScriptWidgetSpotifyAuthorization?
        var callback: (@MainActor (Result<URL, ScriptWidgetServiceError>) -> Void)?
        var starts = 0, cancelled = false
        func start(_ authorization: ScriptWidgetSpotifyAuthorization, completion: @escaping @MainActor (Result<URL, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
            self.authorization = authorization; callback = completion; starts += 1
            return .init { self.cancelled = true }
        }
        func success() {
            guard let authorization else { return XCTFail("Browser session was not started") }
            let state = URLComponents(url: authorization.authorizationURL, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "state" }!.value!
            var url = URLComponents(string: ScriptWidgetSpotifyAuthorization.redirectURI)!
            url.queryItems = [.init(name: "state", value: state), .init(name: "code", value: "sample-provider-code")]
            callback?(.success(url.url!))
        }
    }
    private func store(_ memory: Memory) -> ScriptWidgetServiceConnections {
        let lock = NSLock()
        return .init(keychain: memory, coordinate: { action in lock.lock(); defer { lock.unlock() }; try action() })
    }
    private var token: ScriptWidgetServiceHTTPResponse {
        .init(status: 200, body: Data(#"{"access_token":"sample-spotify-access","refresh_token":"sample-spotify-refresh","token_type":"Bearer","expires_in":3600,"scope":"user-read-private user-read-playback-state"}"#.utf8))
    }
    private func profile(_ subject: String = "sample-listener") -> ScriptWidgetServiceHTTPResponse {
        .init(status: 200, body: try! JSONSerialization.data(withJSONObject: ["id": subject, "display_name": "Sample listener"]))
    }
    private func fixture(_ store: ScriptWidgetServiceConnections, _ tokens: HTTP, _ profiles: HTTP) -> ScriptWidgetSpotifyAccountsModel {
        .init(clientID: clientID, store: store, tokens: .init(transport: tokens), reader: .init(transport: profiles), loadOwners: { [] })
    }
    private func wait(_ model: ScriptWidgetSpotifyAccountsModel, _ phase: ScriptWidgetSpotifyAccountsModel.Phase,
                      file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if model.phase == phase { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Expected account flow phase did not arrive", file: file, line: line)
    }
    private func saved(_ store: ScriptWidgetServiceConnections) throws -> ScriptWidgetServiceConnection {
        let now = Date()
        let credential = ScriptWidgetServiceCredential(formatVersion: 1, accountID: UUID(), service: .spotify, revision: UUID(), accessToken: "sample-previous-access", refreshToken: "sample-previous-refresh", oauthClientID: clientID, issuedAt: now, expiresAt: now.addingTimeInterval(60), scopes: ScriptWidgetSpotifyAuthorization.readScopes)
        let profile = ScriptWidgetServiceProfile(service: .spotify, subject: "sample-listener", username: nil, displayName: "Sample listener", publicRepositories: nil, privateRepositories: nil, followers: nil, following: nil)
        return try store.connect(credential, verifiedProfile: profile, expectedRevision: nil)
    }

    func testNativeConfigurationRequiresClientAndDedicatedRegisteredCallback() {
        let types = [["CFBundleURLSchemes": [ScriptWidgetSpotifyAuthorization.callbackScheme]]]
        XCTAssertEqual(ScriptWidgetSpotifyConfiguration.clientID(info: ["ScriptWidgetSpotifyClientID": clientID, "CFBundleURLTypes": types]), clientID)
        for client: Any in ["", "$(UNCONFIGURED_CLIENT)", "client with spaces", true] {
            XCTAssertNil(ScriptWidgetSpotifyConfiguration.clientID(info: ["ScriptWidgetSpotifyClientID": client, "CFBundleURLTypes": types]))
        }
        XCTAssertNil(ScriptWidgetSpotifyConfiguration.clientID(info: ["ScriptWidgetSpotifyClientID": clientID]))
        XCTAssertNil(ScriptWidgetSpotifyConfiguration.clientID(info: ["ScriptWidgetSpotifyClientID": clientID, "CFBundleURLTypes": [["CFBundleURLSchemes": ["scriptwidget"]]]]))
        let nativeTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let nativeSchemes = nativeTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(nativeSchemes.contains(ScriptWidgetSpotifyAuthorization.callbackScheme))
        XCTAssertTrue(nativeSchemes.contains("scriptwidget"), "Existing widget links stay registered")
        let nativeClient = Bundle.main.object(forInfoDictionaryKey: "ScriptWidgetSpotifyClientID") as? String
        if nativeClient?.isEmpty != false { XCTAssertNil(ScriptWidgetSpotifyConfiguration.clientID) }
        else { XCTAssertEqual(ScriptWidgetSpotifyConfiguration.clientID, nativeClient) }
    }

    func testSignInExchangesThenVerifiesBeforeAtomicallySavingWithoutGrants() async throws {
        let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP(), browser = Browser()
        let model = fixture(store, tokens, profiles); defer { model.cancel() }
        model.reload(); model.connect(using: browser); XCTAssertEqual(model.phase, .authorizing)
        XCTAssertTrue(memory.values.isEmpty); browser.success()
        try await wait(model, .exchanging)
        XCTAssertEqual(tokens.requests.count, 1); XCTAssertTrue(memory.values.isEmpty)
        tokens.callbacks[0](.success(token)); try await wait(model, .verifying)
        XCTAssertEqual(profiles.requests.first?.url?.host, "api.spotify.com"); XCTAssertTrue(memory.values.isEmpty)
        profiles.callbacks[0](.success(profile())); try await wait(model, .idle)
        let connection = try XCTUnwrap(store.connection(.spotify))
        XCTAssertEqual(model.connection?.label, "Sample listener"); XCTAssertEqual(connection.subject, "sample-listener")
        XCTAssertTrue(connection.policy.grants.isEmpty); XCTAssertEqual(memory.values.count, 1); XCTAssertNil(model.message)
    }

    func testCancelAtEverySignInPhaseDiscardsLateCallbacksAndSavesNothing() async throws {
        for phase in [ScriptWidgetSpotifyAccountsModel.Phase.authorizing, .exchanging, .verifying] {
            let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP(), browser = Browser()
            let model = fixture(store, tokens, profiles); model.reload(); model.connect(using: browser)
            if phase != .authorizing { browser.success(); try await wait(model, .exchanging) }
            if phase == .verifying { tokens.callbacks[0](.success(token)); try await wait(model, .verifying) }
            model.cancel(); browser.success()
            for callback in tokens.callbacks { callback(.success(token)) }
            for callback in profiles.callbacks { callback(.success(profile())) }
            try await Task.sleep(nanoseconds: 20_000_000)
            XCTAssertEqual(model.phase, .idle); XCTAssertNil(model.connection); XCTAssertTrue(memory.values.isEmpty)
            XCTAssertTrue(phase == .authorizing ? browser.cancelled : phase == .exchanging ? tokens.cancelled : profiles.cancelled)
        }
    }

    func testWrongCallbackNeverStartsHTTPAndCompetingConnectionCannotBeOverwritten() async throws {
        let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP(), browser = Browser()
        let model = fixture(store, tokens, profiles); defer { model.cancel() }
        model.reload(); model.connect(using: browser)
        browser.callback?(.success(URL(string: "scriptwidget://oauth/spotify/callback?code=wrong")!))
        try await wait(model, .idle)
        XCTAssertTrue(tokens.requests.isEmpty); XCTAssertTrue(memory.values.isEmpty)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.invalidCallback.localizedDescription)
        model.connect(using: browser)
        let winner = try saved(store)
        browser.success(); try await wait(model, .idle)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.conflict.localizedDescription)
        XCTAssertTrue(tokens.requests.isEmpty); XCTAssertEqual(try store.connection(.spotify)?.revision, winner.revision)
    }

    func testConnectionChangedDuringProfileVerificationRejectsOldSignIn() async throws {
        let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP(), browser = Browser()
        let model = fixture(store, tokens, profiles); defer { model.cancel() }
        model.reload(); model.connect(using: browser); browser.success(); try await wait(model, .exchanging)
        tokens.callbacks[0](.success(token)); try await wait(model, .verifying)
        let winner = try saved(store)
        profiles.callbacks[0](.success(profile())); try await wait(model, .idle)
        XCTAssertEqual(try store.connection(.spotify)?.credential.revision, winner.credential.revision)
        XCTAssertNotNil(model.message)
    }

    func testRefreshVerifiesSameProviderSubjectAndRetainsOwnerPolicy() async throws {
        let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP()
        let original = try saved(store)
        let granted = try store.setGrant(service: .spotify, ownerID: UUID(), operations: [.spotifyProfile, .spotifyPlayback], expectedRevision: original.revision)
        let model = fixture(store, tokens, profiles); defer { model.cancel() }; model.reload()
        model.refresh(); XCTAssertEqual(tokens.requests.count, 1)
        tokens.callbacks[0](.success(token)); try await wait(model, .verifyingRefresh)
        profiles.callbacks[0](.success(profile("another-account"))); try await wait(model, .idle)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.invalidCredential.localizedDescription)
        XCTAssertEqual(try store.connection(.spotify)?.credential.revision, granted.credential.revision)
        model.refresh(); tokens.callbacks[1](.success(token)); try await wait(model, .verifyingRefresh)
        profiles.callbacks[1](.success(profile())); try await wait(model, .idle)
        let current = try XCTUnwrap(store.connection(.spotify))
        XCTAssertNotEqual(current.credential.revision, granted.credential.revision)
        XCTAssertEqual(current.policy.revision, granted.policy.revision)
        XCTAssertEqual(current.policy.grants.map(\.ownerID), granted.policy.grants.map(\.ownerID))
        XCTAssertEqual(current.policy.grants.map(\.operations), granted.policy.grants.map(\.operations))
        XCTAssertNil(model.message)
    }

    func testDisconnectedAccountCannotBeResurrectedByPendingRefresh() async throws {
        let memory = Memory(), store = store(memory), tokens = HTTP(), profiles = HTTP()
        let original = try saved(store), model = fixture(store, tokens, profiles); defer { model.cancel() }
        model.reload(); model.refresh(); try store.disconnect(.spotify, expectedRevision: original.revision)
        tokens.callbacks[0](.success(token)); try await wait(model, .idle)
        XCTAssertNil(try store.connection(.spotify)); XCTAssertTrue(profiles.requests.isEmpty)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.notConnected.localizedDescription)
    }

    func testForegroundLeaseSerializesScreensAndOldCallbacksCannotReleaseNewLease() async throws {
        let memory = Memory(), store = store(memory)
        let first = fixture(store, HTTP(), HTTP()), second = fixture(store, HTTP(), HTTP()), third = fixture(store, HTTP(), HTTP())
        defer { first.cancel(); second.cancel(); third.cancel() }
        let one = Browser(), two = Browser(), three = Browser()
        first.reload(); second.reload(); third.reload(); first.connect(using: one); second.connect(using: two)
        XCTAssertEqual(two.starts, 0); XCTAssertEqual(second.message, ScriptWidgetServiceError.conflict.localizedDescription)
        first.cancel(); second.connect(using: two); XCTAssertEqual(two.starts, 1)
        one.callback?(.failure(.cancelled)); try await Task.sleep(nanoseconds: 20_000_000)
        third.connect(using: three); XCTAssertEqual(three.starts, 0)
        XCTAssertEqual(third.message, ScriptWidgetServiceError.conflict.localizedDescription)
    }

    func testSpotifyProfileGrantChecksOwnerAndPreservesOtherReadOperations() throws {
        let memory = Memory(), store = store(memory), connection = try saved(store), id = UUID()
        _ = try store.setGrant(service: .spotify, ownerID: id, operations: [.spotifyPlayback], expectedRevision: connection.revision)
        var retired = true
        let owner = ScriptWidgetServiceAccountsModel.Owner(id: id, name: "My Spotify widget", validate: { if retired { throw ScriptWidgetServiceError.conflict } })
        let model = ScriptWidgetSpotifyAccountsModel(clientID: clientID, store: store, tokens: .init(transport: HTTP()), reader: .init(transport: HTTP()), loadOwners: { [owner] })
        model.reload(); model.setGranted(true, owner: owner)
        XCTAssertEqual(model.message, ScriptWidgetServiceError.conflict.localizedDescription)
        XCTAssertFalse(model.connection!.grantedOwners.contains(id))
        retired = false; model.setGranted(true, owner: owner)
        XCTAssertEqual(try store.connection(.spotify)?.policy.grants.first?.operations, [.spotifyProfile, .spotifyPlayback])
        XCTAssertEqual(model.connection?.grantedOwners, [id])
        model.setGranted(false, owner: owner)
        XCTAssertEqual(try store.connection(.spotify)?.policy.grants.first?.operations, [.spotifyPlayback])
        XCTAssertTrue(model.connection!.grantedOwners.isEmpty)
        XCTAssertEqual(model.connection!.playbackOwners,[id])
        model.setGranted(false, owner:owner, operation:.spotifyPlayback)
        XCTAssertTrue(model.connection!.playbackOwners.isEmpty)
        model.setGranted(true, owner:owner, operation:.spotifyPlayback)
        XCTAssertEqual(try store.connection(.spotify)?.policy.grants.first?.operations,[.spotifyPlayback])
        model.setGranted(true, owner:owner, operation:.spotifyPause)
        XCTAssertEqual(try store.connection(.spotify)?.policy.grants.first?.operations,[.spotifyPlayback])
    }

    func testActualPresentationWindowBridgeUsesHostWindowAndSystemCallbackScheme() async throws {
        let reference = ScriptWidgetServiceWindowReference()
        let content = Text("Account presentation").background(ScriptWidgetServicePresentationWindow(reference: reference))
        #if os(macOS)
        let host = NSHostingView(rootView: content), window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host; window.orderFront(nil); defer { window.orderOut(nil) }
        #else
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene), controller = UIHostingController(rootView: content)
        window.rootViewController = controller; window.makeKeyAndVisible(); defer { window.isHidden = true; previous?.makeKey() }
        #endif
        for _ in 0..<100 { if reference.window != nil { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(reference.window === window)
        if #available(iOS 17.4, macOS 14.4, *) {
            let callback = ASWebAuthenticationSession.Callback.customScheme(ScriptWidgetSpotifyAuthorization.callbackScheme)
            XCTAssertTrue(callback.matchesURL(URL(string: ScriptWidgetSpotifyAuthorization.redirectURI)!))
            XCTAssertFalse(callback.matchesURL(URL(string: "scriptwidget://oauth/spotify/callback")!))
        }
        reference.update(nil); XCTAssertNil(reference.window)
    }

    func testSpotifyAccountScreenshots() async throws {
        guard let path = ProcessInfo.processInfo.environment["SCRIPTWIDGET_EXPORT_SPOTIFY_ACCOUNTS"] else {
            throw XCTSkip("Set TEST_RUNNER_SCRIPTWIDGET_EXPORT_SPOTIFY_ACCOUNTS for isolated account screenshots")
        }
        #if os(macOS)
        let platform = "macos"
        #else
        let platform = "ios"
        #endif
        let directory = URL(fileURLWithPath: path).appendingPathComponent(platform)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for state in ["unconfigured", "ready", "authorizing", "connected"] {
            let memory = Memory(), store = store(memory)
            let screenshotOwner = ScriptWidgetServiceAccountsModel.Owner(id: UUID(), name: "My Spotify widget", validate: {})
            if state == "connected" { _ = try saved(store) }
            let spotify = ScriptWidgetSpotifyAccountsModel(clientID: state == "unconfigured" ? nil : clientID, store: store,
                tokens: .init(transport: HTTP()), reader: .init(transport: HTTP()),
                loadOwners: { state == "connected" ? [screenshotOwner] : [] })
            spotify.reload(); if state == "authorizing" { spotify.connect(using: Browser()) }
            if state == "connected", let owner = spotify.owners.first { spotify.setGranted(true, owner: owner) }
            defer { spotify.cancel() }
            let github = ScriptWidgetServiceAccountsModel(store: store, loadOwners: { [] }); github.reload()
            let content = NavigationStack { ScriptWidgetServiceAccountsView(model: github, spotifyModel: spotify) }.environment(\.colorScheme, .light)
            #if os(macOS)
            let host = NSHostingView(rootView: content.background(Color.white)); host.frame = NSRect(x: 0, y: 0, width: 620, height: 900)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua); window.contentView = host; window.orderFront(nil)
            defer { window.orderOut(nil) }
            host.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 150_000_000)
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            #else
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first { $0.isKeyWindow }, window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            let controller = UIHostingController(rootView: content); window.rootViewController = controller
            window.makeKeyAndVisible(); controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
            defer { window.isHidden = true; previous?.makeKey() }
            try await Task.sleep(nanoseconds: 150_000_000)
            if state != "unconfigured" {
                func scrollToBottom(_ view: UIView) {
                    if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                        scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    }
                    for child in view.subviews { scrollToBottom(child) }
                }
                scrollToBottom(controller.view); controller.view.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let png = try XCTUnwrap(image.pngData())
            #endif
            try png.write(to: directory.appendingPathComponent(state + ".png"))
        }
    }
}
#endif
