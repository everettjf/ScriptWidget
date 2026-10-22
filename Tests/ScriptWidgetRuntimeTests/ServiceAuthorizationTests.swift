import Foundation
import Security
import XCTest
#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
@testable import ScriptWidget
#endif

final class ServiceAuthorizationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func credential(accountID: UUID = UUID()) -> ScriptWidgetServiceCredential {
        .init(formatVersion: 1, accountID: accountID, service: .github, revision: UUID(),
            accessToken: "sample-access-token", refreshToken: nil, oauthClientID: nil,
            issuedAt: now, expiresAt: now.addingTimeInterval(3600), scopes: [])
    }
    private func fails(_ expected: ScriptWidgetServiceError, _ operation: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { XCTAssertEqual($0 as? ScriptWidgetServiceError, expected, file: file, line: line) }
    }
    @objc func testCredentialEnvelopeRejectsMalformedValuesAndUnknownFields() throws {
        let value = credential(), encoded = try value.encoded()
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(encoded, accountID: UUID(), service: .github))
        let original = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for patch: [String: Any] in [["formatVersion": 2], ["unexpected": true], ["issuedAt": -1],
            ["expiresAt": now.timeIntervalSince1970], ["accessToken": "header\ninjection"], ["scopes": ["unknown"]],
            ["refreshToken": "unsupported-refresh"], ["oauthClientID": "unsupported-client"], ["service": "removed-provider"]] {
            let changed = original.merging(patch, uniquingKeysWith: { _, new in new })
            XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(JSONSerialization.data(withJSONObject: changed), accountID: value.accountID, service: .github))
        }
        XCTAssertThrowsError(try ScriptWidgetServiceCredential.decode(Data(repeating: 32, count: 16385), accountID: value.accountID, service: .github))
    }
    @objc func testCredentialsRemainRedactedAndOnlyGitHubIsSupported() throws {
        let value = credential()
        XCTAssertFalse(String(describing: value).contains(value.accessToken))
        XCTAssertFalse(String(reflecting: value).contains(value.accessToken))
        XCTAssertEqual(ScriptWidgetService.allCases, [.github])
        XCTAssertNil(ScriptWidgetService(rawValue: "removed-provider"))
        XCTAssertEqual(try ScriptWidgetServiceCredential.decode(value.encoded(), accountID: value.accountID, service: .github).revision, value.revision)
    }

    private final class MemoryKeychain: ScriptWidgetServiceKeychainAccess {
        var values: [String: Data] = [:]
        var failure: ScriptWidgetServiceError?
        func read(_ account: String) throws -> Data? { if let failure { throw failure }; return values[account] }
        func write(_ data: Data, account: String) throws { if let failure { throw failure }; values[account] = data }
        func remove(_ account: String) throws { if let failure { throw failure }; values.removeValue(forKey: account) }
    }

    @objc func testVaultSeparatesServiceAccountAndCredentialRevision() throws {
        let memory = MemoryKeychain(), vault = ScriptWidgetServiceCredentialVault(keychain: memory), a = credential(), b = credential()
        try vault.write(a); try vault.write(b)
        XCTAssertEqual(memory.values.count, 2)
        XCTAssertEqual(try vault.read(service: a.service, accountID: a.accountID, revision: a.revision)?.accessToken, a.accessToken)
        XCTAssertNil(try vault.read(service: a.service, accountID: UUID(), revision: b.revision))
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
