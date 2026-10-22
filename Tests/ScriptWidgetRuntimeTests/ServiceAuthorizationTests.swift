import Foundation
import Security
import XCTest
#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
@testable import ScriptWidget
#endif

final class ServiceAuthorizationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let clientID = "0123456789abcdef0123456789abcdef"

    private func pending(control: Bool = false) throws -> ScriptWidgetSpotifyAuthorization {
        try ScriptWidgetSpotifyAuthorization(clientID: clientID, playbackControl: control, now: now, random: { [UInt8](repeating: UInt8($0), count: $0) })
    }
    private func state(_ session: ScriptWidgetSpotifyAuthorization) -> String {
        URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "state" }!.value!
    }
    private func callback(_ session: ScriptWidgetSpotifyAuthorization, code: String = "sample-code") -> URL {
        var parts = URLComponents(string: ScriptWidgetSpotifyAuthorization.redirectURI)!
        parts.queryItems = [URLQueryItem(name: "code", value: code), URLQueryItem(name: "state", value: state(session))]
        return parts.url!
    }
    private func response(_ patch: [String: Any] = [:]) throws -> Data {
        let base: [String: Any] = ["access_token": "sample-access-token", "refresh_token": "sample-refresh-token", "token_type": "Bearer", "expires_in": 3600, "scope": ScriptWidgetSpotifyAuthorization.readScopes.sorted().joined(separator: " ")]
        return try JSONSerialization.data(withJSONObject: base.merging(patch, uniquingKeysWith: { _, new in new }))
    }
    private func credential(service: ScriptWidgetService = .spotify, accountID: UUID = UUID(), revision: UUID = UUID()) -> ScriptWidgetServiceCredential {
        ScriptWidgetServiceCredential(formatVersion: 1, accountID: accountID, service: service, revision: revision,
            accessToken: "sample-access-token", refreshToken: service == .spotify ? "sample-refresh-token" : nil,
            oauthClientID: service == .spotify ? clientID : nil, issuedAt: now, expiresAt: service == .spotify ? now.addingTimeInterval(3600) : nil,
            scopes: service == .spotify ? ScriptWidgetSpotifyAuthorization.readScopes : [])
    }
    private func fails(_ expected: ScriptWidgetServiceError, _ operation: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { XCTAssertEqual($0 as? ScriptWidgetServiceError, expected, file: file, line: line) }
    }

    @objc func testPKCEUsesRFC7636S256AndSeparatesReadFromControlScopes() throws {
        XCTAssertEqual(ScriptWidgetSpotifyAuthorization.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let read = try pending(), control = try pending(control: true)
        let parts = URLComponents(url: read.authorizationURL, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(parts.scheme, "https"); XCTAssertEqual(parts.host, "accounts.spotify.com")
        let items = Dictionary(uniqueKeysWithValues: parts.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(items["code_challenge_method"], "S256"); XCTAssertEqual(items["state"]?.count, 43)
        XCTAssertEqual(items["code_challenge"]?.count, 43); XCTAssertNil(items["code_verifier"])
        XCTAssertFalse(read.requestedScopes.contains("user-modify-playback-state"))
        XCTAssertTrue(control.requestedScopes.contains("user-modify-playback-state"))
        XCTAssertEqual(items["redirect_uri"], ScriptWidgetSpotifyAuthorization.redirectURI)
    }

    @objc func testInvalidConfigurationAndBrokenRandomnessCannotStartAuthorization() {
        for value in ["", "short", "https://attacker.test", "client\nidentifier"] {
            fails(.invalidConfiguration) { _ = try ScriptWidgetSpotifyAuthorization(clientID: value, playbackControl: false) }
        }
        fails(.authorizationFailed) { _ = try ScriptWidgetSpotifyAuthorization(clientID: clientID, playbackControl: false, random: { _ in [] }) }
    }

    @objc func testCallbackRejectsWrongOriginStateDuplicatesAndEncodedPathBeforeRedemption() throws {
        for mutation in ["scheme", "host", "path", "encodedPath", "port", "user", "fragment", "state", "duplicateState", "duplicateCode", "mixed", "unknown"] {
            let session = try pending(); var parts = URLComponents(url: callback(session), resolvingAgainstBaseURL: false)!
            switch mutation {
            case "scheme": parts.scheme = "https"
            case "host": parts.host = "oauth.attacker.test"
            case "path": parts.path = "/other/callback"
            case "encodedPath": parts.percentEncodedPath = "/spotify%2Fcallback"
            case "port": parts.port = 443
            case "user": parts.user = "user"
            case "fragment": parts.fragment = "code=unexpected"
            case "state": parts.queryItems = parts.queryItems!.map { $0.name == "state" ? .init(name: "state", value: "wrong") : $0 }
            case "duplicateState": parts.queryItems!.append(.init(name: "state", value: state(session)))
            case "duplicateCode": parts.queryItems!.append(.init(name: "code", value: "other"))
            case "mixed": parts.queryItems!.append(.init(name: "error", value: "access_denied"))
            default: parts.queryItems!.append(.init(name: "redirect_uri", value: "https://attacker.test"))
            }
            fails(.invalidCallback) { _ = try session.tokenRequest(callback: parts.url!, now: now) }
            // An unrelated/malformed callback has not consumed the valid session.
            XCTAssertEqual(try session.tokenRequest(callback: callback(session), now: now).url, ScriptWidgetSpotifyAuthorization.tokenURL)
        }
    }

    @objc func testCallbackIsSingleUseAndDoesNotPutVerifierInURLOrAcceptCancelledSession() throws {
        let session = try pending(), request = try session.tokenRequest(callback: callback(session, code: "code+/=&"), now: now)
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertNil(request.url?.query); XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8)!
        XCTAssertTrue(body.contains("code=code%2B%2F%3D%26")); XCTAssertTrue(body.contains("code_verifier="))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        fails(.consumedAuthorization) { _ = try session.tokenRequest(callback: callback(session), now: now) }
        let cancelled = try pending()
        var parts = URLComponents(string: ScriptWidgetSpotifyAuthorization.redirectURI)!
        parts.queryItems = [.init(name: "state", value: state(cancelled)), .init(name: "error", value: "access_denied"), .init(name: "error_description", value: "provider-private-message")]
        fails(.cancelled) { _ = try cancelled.tokenRequest(callback: parts.url!, now: now) }
        XCTAssertFalse(ScriptWidgetServiceError.cancelled.localizedDescription.contains("provider-private-message"))
        fails(.consumedAuthorization) { _ = try cancelled.tokenRequest(callback: callback(cancelled), now: now) }
    }

    @objc func testAuthorizationHasBoundedLifetimeAndStateIsNotCopyableForReplay() throws {
        for date in [now.addingTimeInterval(-1), now.addingTimeInterval(301)] {
            let session = try pending()
            fails(.expiredAuthorization) { _ = try session.tokenRequest(callback: callback(session), now: date) }
            fails(.consumedAuthorization) { _ = try session.tokenRequest(callback: callback(session), now: now) }
        }
        let session = try pending(), alias = session
        _ = try session.tokenRequest(callback: callback(session), now: now)
        fails(.consumedAuthorization) { _ = try alias.tokenRequest(callback: callback(alias), now: now) }
    }

    @objc func testSystemEntropyProducesDistinctAuthorizationStates() throws {
        let a = try ScriptWidgetSpotifyAuthorization(clientID: clientID, playbackControl: false)
        let b = try ScriptWidgetSpotifyAuthorization(clientID: clientID, playbackControl: false)
        XCTAssertNotEqual(state(a), state(b))
    }

    @objc func testConcurrentCallbacksCannotRedeemTheSameAuthorizationTwice() throws {
        final class Counts: @unchecked Sendable {
            let lock = NSLock()
            var success = 0, replay = 0, unexpected = 0
        }
        let session = try pending(), url = callback(session), date = now, group = DispatchGroup(), counts = Counts()
        for _ in 0..<16 {
            group.enter()
            DispatchQueue.global().async {
                defer { group.leave() }
                let result: Int
                do { _ = try session.tokenRequest(callback: url, now: date); result = 0 }
                catch ScriptWidgetServiceError.consumedAuthorization { result = 1 }
                catch { result = 2 }
                counts.lock.lock(); defer { counts.lock.unlock() }
                if result == 0 { counts.success += 1 } else if result == 1 { counts.replay += 1 } else { counts.unexpected += 1 }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + .seconds(2)), .success)
        counts.lock.lock(); defer { counts.lock.unlock() }
        XCTAssertEqual(counts.success, 1); XCTAssertEqual(counts.replay, 15); XCTAssertEqual(counts.unexpected, 0)
    }

    @objc func testTokenResponseBindsAccountScopesAndRedactsDescriptions() throws {
        let id = UUID(), value = try ScriptWidgetSpotifyAuthorization.credential(response: response(), accountID: id, clientID: clientID, requestedScopes: ScriptWidgetSpotifyAuthorization.readScopes, now: now)
        XCTAssertEqual(value.accountID, id); XCTAssertEqual(value.service, .spotify)
        XCTAssertEqual(value.expiresAt, now.addingTimeInterval(3600))
        XCTAssertEqual(value.scopes, ScriptWidgetSpotifyAuthorization.readScopes)
        XCTAssertFalse(String(describing: value).contains("sample-access-token"))
        XCTAssertFalse(String(reflecting: value).contains("sample-refresh-token"))
        XCTAssertEqual(try ScriptWidgetServiceCredential.decode(value.encoded(), accountID: id, service: .spotify).revision, value.revision)
    }

    @objc func testTokenResponseRejectsHeaderInjectionInvalidExpiryAndMissingGrants() throws {
        for patch: [String: Any] in [["access_token": "token\r\nInjected: value"], ["refresh_token": ""], ["token_type": "Basic"], ["expires_in": true], ["expires_in": 0], ["expires_in": 86401], ["expires_in": 1.5], ["scope": NSNull()], ["scope": "user-read-private"], ["unknown": "extra"]] {
            XCTAssertThrowsError(try ScriptWidgetSpotifyAuthorization.credential(response: response(patch), accountID: UUID(), clientID: clientID, requestedScopes: ScriptWidgetSpotifyAuthorization.readScopes, now: now))
        }
        XCTAssertThrowsError(try ScriptWidgetSpotifyAuthorization.credential(response: Data(repeating: 32, count: 16385), accountID: UUID(), clientID: clientID, requestedScopes: ScriptWidgetSpotifyAuthorization.readScopes, now: now))
    }

    @objc func testCredentialExpiryIsBoundedByItsNativeIssueTime() throws {
        let value = credential(), encoded = try value.encoded()
        for patch: [String: Any] in [["issuedAt": -1], ["expiresAt": now.timeIntervalSince1970], ["expiresAt": now.addingTimeInterval(86401).timeIntervalSince1970], ["refreshToken": NSNull()]] {
            let object = (try JSONSerialization.jsonObject(with: encoded) as! [String: Any]).merging(patch, uniquingKeysWith: { _, new in new })
            XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(JSONSerialization.data(withJSONObject: object), accountID: value.accountID, service: value.service))
        }
    }

    @objc func testRefreshPreservesOmittedScopeAndRotatesTokenWithoutUpgradingAccess() throws {
        let previous = credential()
        var object = try JSONSerialization.jsonObject(with: response()) as! [String: Any]
        object.removeValue(forKey: "scope"); object["refresh_token"] = "rotated-refresh-token"
        let next = try ScriptWidgetSpotifyAuthorization.credential(response: JSONSerialization.data(withJSONObject: object), accountID: previous.accountID, clientID: clientID, requestedScopes: previous.scopes, previous: previous, now: now)
        XCTAssertEqual(next.refreshToken, "rotated-refresh-token"); XCTAssertEqual(next.scopes, previous.scopes); XCTAssertNotEqual(next.revision, previous.revision)
        XCTAssertThrowsError(try ScriptWidgetSpotifyAuthorization.credential(response: response(), accountID: UUID(), clientID: clientID, requestedScopes: previous.scopes, previous: previous, now: now))
        XCTAssertThrowsError(try ScriptWidgetSpotifyAuthorization.credential(response: response(), accountID: previous.accountID, clientID: clientID, requestedScopes: previous.scopes.union(["user-modify-playback-state"]), previous: previous, now: now))
        let request = try ScriptWidgetSpotifyAuthorization.refreshRequest(clientID: clientID, credential: next)
        XCTAssertNil(request.url?.query); XCTAssertEqual(request.url?.host, "accounts.spotify.com")
        XCTAssertFalse(String(describing: request).contains("rotated-refresh-token"))
        fails(.invalidCredential) { _ = try ScriptWidgetSpotifyAuthorization.refreshRequest(clientID: "different-native-client", credential: next) }
    }

    @objc func testCredentialEnvelopeRejectsWrongAccountServiceRevisionAndUnknownFields() throws {
        let value = credential(), encoded = try value.encoded()
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(encoded, accountID: UUID(), service: .spotify))
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(encoded, accountID: value.accountID, service: .github))
        var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        object["unexpected"] = true
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(JSONSerialization.data(withJSONObject: object), accountID: value.accountID, service: .spotify))
        object.removeValue(forKey: "unexpected"); object["formatVersion"] = 2
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(JSONSerialization.data(withJSONObject: object), accountID: value.accountID, service: .spotify))
    }

    private final class MemoryKeychain: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        var failure: ScriptWidgetServiceError?
        func read(_ account: String) throws -> Data? { if let failure { throw failure }; return values[account] }
        func write(_ data: Data, account: String) throws { if let failure { throw failure }; values[account] = data }
        func remove(_ account: String) throws { if let failure { throw failure }; values.removeValue(forKey: account) }
    }

    @objc func testVaultSeparatesServiceAccountAndCredentialRevision() throws {
        let memory = MemoryKeychain(), vault = ScriptWidgetServiceCredentialVault(keychain: memory), a = credential(), b = credential(service: .github)
        try vault.write(a); try vault.write(b)
        XCTAssertEqual(memory.values.count, 2)
        XCTAssertEqual(try vault.read(service: a.service, accountID: a.accountID, revision: a.revision)?.accessToken, a.accessToken)
        XCTAssertNil(try vault.read(service: a.service, accountID: b.accountID, revision: b.revision))
        fails(.invalidCredential) { _ = try vault.read(service: a.service, accountID: a.accountID, revision: UUID()) }
        try vault.remove(service: a.service, accountID: a.accountID)
        XCTAssertNotNil(try vault.read(service: b.service, accountID: b.accountID, revision: b.revision))
    }

    @objc func testVaultNeverConvertsLockedOrCorruptStorageIntoDisconnectedState() throws {
        let memory = MemoryKeychain(), vault = ScriptWidgetServiceCredentialVault(keychain: memory), value = credential()
        try vault.write(value); let before = memory.values
        memory.failure = .locked
        fails(.locked) { _ = try vault.read(service: value.service, accountID: value.accountID, revision: value.revision) }
        fails(.locked) { try vault.write(credential()) }
        XCTAssertEqual(memory.values, before)
        memory.failure = nil; memory.values[memory.values.keys.first!] = Data("invalid".utf8)
        fails(.invalidCredential) { _ = try vault.read(service: value.service, accountID: value.accountID, revision: value.revision) }
    }

    @objc func testSharedServiceGroupCannotFallBackToDefaultAICredentialGroup() throws {
        XCTAssertEqual(try ScriptWidgetServiceSystemKeychain.accessGroup("FAKETEAM01.com.everettjf.scriptwidget.services"), "FAKETEAM01.com.everettjf.scriptwidget.services")
        for value: String? in [nil, "", "$(AppIdentifierPrefix)com.everettjf.scriptwidget.services", "FAKETEAM01.com.everettjf.scriptwidget", "FAKETEAM01.com.everettjf.scriptwidget.ai", "wrong.com.everettjf.scriptwidget.services"] {
            fails(.invalidConfiguration) { _ = try ScriptWidgetServiceSystemKeychain.accessGroup(value) }
        }
    }

    @objc func testKeychainStatusMappingDoesNotExposeProviderErrorsOrSecrets() {
        for status in [errSecInteractionNotAllowed, errSecAuthFailed] { fails(.locked) { try ScriptWidgetServiceSystemKeychain.check(status) } }
        for status in [errSecParam, errSecNotAvailable] { fails(.storageUnavailable) { try ScriptWidgetServiceSystemKeychain.check(status) } }
        XCTAssertNoThrow(try ScriptWidgetServiceSystemKeychain.check(errSecSuccess))
    }
}
