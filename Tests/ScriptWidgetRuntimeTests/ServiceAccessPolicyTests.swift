import Foundation
import XCTest
#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
@testable import ScriptWidget
#endif

final class ServiceAccessPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private func credential(_ service: ScriptWidgetService = .github, controls: Bool = false, accountID: UUID = UUID()) -> ScriptWidgetServiceCredential {
        .init(formatVersion: 1, accountID: accountID, service: service, revision: UUID(), accessToken: "private-sample-bearer",
            refreshToken: nil, oauthClientID: nil, issuedAt: now, expiresAt: now.addingTimeInterval(3600), scopes: [])
    }
    private func grant(_ credential: ScriptWidgetServiceCredential, owner: UUID, operations: Set<ScriptWidgetServiceOperation>) throws -> ScriptWidgetServiceAccessPolicy {
        let empty = ScriptWidgetServiceAccessPolicy.connected(accountID: credential.accountID, service: credential.service)
        return try empty.updatingGrant(ownerID: owner, operations: operations, expectedRevision: empty.revision)
    }
    private func plan(_ operation: ScriptWidgetServiceOperation, _ credential: ScriptWidgetServiceCredential, _ policy: ScriptWidgetServiceAccessPolicy,
                      owner: UUID, connection: UUID? = nil, action: Bool = false, requestID: UUID? = nil, network: Bool = true,
                      hosts: Set<String> = ["api.github.com"], date: Date? = nil) throws -> ScriptWidgetServiceRequestPlan {
        try .init(operation: operation, credential: credential, policy: policy, ownerID: owner,
            expectedConnectionID: connection ?? policy.connectionID, isUserInitiatedAction: action, requestID: requestID,
            hasNetworkPermission: network, allowsHost: { hosts.contains($0) }, now: date ?? now)
    }

    @objc func testConnectedAccountNeverGrantsEveryWidgetAccessByDefault() throws {
        let value = credential(), owner = UUID(), empty = ScriptWidgetServiceAccessPolicy.connected(accountID: value.accountID, service: .github)
        XCTAssertTrue(empty.grants.isEmpty)
        XCTAssertThrowsError(try plan(.githubProfile, value, empty, owner: owner))
        let allowed = try empty.updatingGrant(ownerID: owner, operations: [.githubProfile], expectedRevision: empty.revision)
        XCTAssertNoThrow(try plan(.githubProfile, value, allowed, owner: owner))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: UUID()))
    }

    @objc func testAccountServiceAndConnectionCannotBeSubstitutedAcrossGrants() throws {
        let value = credential(), owner = UUID(), allowed = try grant(value, owner: owner, operations: [.githubProfile])
        XCTAssertThrowsError(try plan(.githubProfile, credential(), allowed, owner: owner))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, connection: UUID()))
    }

    @objc func testAuthenticatedRequestsRequireNetworkAndEveryNativeServiceHost() throws {
        let value = credential(), owner = UUID(), allowed = try grant(value, owner: owner, operations: [.githubProfile])
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, network: false))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, hosts: []))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, hosts: ["api.github.com.attacker.test"]))
        XCTAssertNoThrow(try plan(.githubProfile, value, allowed, owner: owner))
    }

    @objc func testRevocationExpiryAndStaleSettingsStopRequestsWithoutErasingCredentials() throws {
        let value = credential(), owner = UUID(), allowed = try grant(value, owner: owner, operations: [.githubProfile])
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed.revoked(), owner: owner))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, date: now.addingTimeInterval(4000)))
        XCTAssertThrowsError(try plan(.githubProfile, value, allowed, owner: owner, date: now.addingTimeInterval(-120)))
        let removed = try allowed.updatingGrant(ownerID: owner, operations: [], expectedRevision: allowed.revision)
        XCTAssertTrue(removed.grants.isEmpty); XCTAssertEqual(allowed.grants.count, 1)
        XCTAssertThrowsError(try removed.updatingGrant(ownerID: owner, operations: [.githubProfile], expectedRevision: allowed.revision))
        XCTAssertThrowsError(try plan(.githubProfile, value, removed, owner: owner))
        XCTAssertNoThrow(try value.validate())
    }

    @objc func testPolicyCodecRejectsUnknownVersionKeysDuplicateOwnersAndForeignOperations() throws {
        let value = credential(), owner = UUID(), allowed = try grant(value, owner: owner, operations: [.githubProfile])
        let data = try allowed.encoded()
        XCTAssertEqual(try ScriptWidgetServiceAccessPolicy.decode(data, accountID: value.accountID, service: .github).revision, allowed.revision)
        var original = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for patch: [String: Any] in [["formatVersion": 2], ["url": "https://attacker.test"], ["grants": [["ownerID": owner.uuidString, "operations": ["github.profile"]], ["ownerID": owner.uuidString, "operations": ["github.profile"]]]], ["grants": [["ownerID": owner.uuidString, "operations": ["unsupported.write"]]]], ["grants": [["ownerID": owner.uuidString, "operations": ["github.profile"], "extra": true]]]] {
            let changed = original.merging(patch, uniquingKeysWith: { _, new in new })
            XCTAssertThrowsError(try ScriptWidgetServiceAccessPolicy.decode(JSONSerialization.data(withJSONObject: changed), accountID: value.accountID, service: .github))
        }
        original["grants"] = Array(repeating: ["ownerID": UUID().uuidString, "operations": ["github.profile"]] as [String: Any], count: 33)
        XCTAssertThrowsError(try ScriptWidgetServiceAccessPolicy.decode(JSONSerialization.data(withJSONObject: original), accountID: value.accountID, service: .github))
        XCTAssertThrowsError(try ScriptWidgetServiceAccessPolicy.decode(Data(repeating: 32, count: 16385), accountID: value.accountID, service: .github))
    }

    @objc func testPlansHaveOnlyFixedFirstPartyEndpointsAndRedactBearerDescriptions() throws {
        let expected: [(ScriptWidgetServiceOperation, String, String)] = [(.githubProfile, "GET", "https://api.github.com/user")]
        for (operation, method, url) in expected {
            let value = credential(operation.service, controls: true), owner = UUID(), allowed = try grant(value, owner: owner, operations: [operation])
            let built = try plan(operation, value, allowed, owner: owner, action: true, requestID: UUID())
            XCTAssertEqual(built.request.httpMethod, method); XCTAssertEqual(built.request.url?.absoluteString, url)
            XCTAssertEqual(built.request.value(forHTTPHeaderField: "Authorization"), "Bearer private-sample-bearer")
            XCTAssertNil(built.request.url?.user); XCTAssertNil(built.request.url?.password); XCTAssertNil(built.request.url?.query)
            XCTAssertFalse(built.request.httpShouldHandleCookies)
            XCTAssertFalse(String(reflecting: built).contains("private-sample-bearer"))
            XCTAssertFalse(String(describing: allowed).contains(owner.uuidString))
        }
        XCTAssertNil(ScriptWidgetServiceOperation(rawValue: "https://attacker.test/profile"))
        XCTAssertNil(ScriptWidgetServiceOperation(rawValue: "unsupported.arbitrary"))
    }

    @objc func testPolicyAndCredentialOccupySeparateNativeKeychainItems() throws {
        final class Memory: ScriptWidgetServiceKeychainAccess {
            var values: [String: Data] = [:]
            func read(_ account: String) throws -> Data? { values[account] }
            func write(_ data: Data, account: String) throws { values[account] = data }
            func remove(_ account: String) throws { values.removeValue(forKey: account) }
        }
        let memory = Memory(), vault = ScriptWidgetServiceCredentialVault(keychain: memory), value = credential()
        let allowed = try grant(value, owner: UUID(), operations: [.githubProfile])
        try vault.write(value); try vault.writePolicy(allowed)
        XCTAssertEqual(memory.values.count, 2)
        XCTAssertEqual(try vault.readPolicy(service: .github, accountID: value.accountID)?.revision, allowed.revision)
        XCTAssertNil(try vault.readPolicy(service: .github, accountID: UUID()))
        try vault.removePolicy(service: .github, accountID: value.accountID)
        XCTAssertNil(try vault.readPolicy(service: .github, accountID: value.accountID))
        XCTAssertEqual(try vault.read(service: .github, accountID: value.accountID, revision: value.revision)?.revision, value.revision)
    }
}
