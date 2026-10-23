import Foundation
import Security
import LocalAuthentication

protocol ScriptWidgetServiceKeychainAccess {
    func read(_ account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func remove(_ account: String) throws
}

/// Service-only sharing between the app and its widget extension. The app's
/// default (AI) credential group stays separate. No handle or token crosses JS.
struct ScriptWidgetServiceSystemKeychain: ScriptWidgetServiceKeychainAccess {
    private static let service = "com.everettjf.scriptwidget.services.v1"

    private func query(_ account: String) throws -> [String: Any] {
        let group = try Self.accessGroup(Bundle.main.object(forInfoDictionaryKey: "ScriptWidgetServiceKeychainGroup") as? String)
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account, kSecAttrAccessGroup as String: group, kSecAttrSynchronizable as String: false]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    static func accessGroup(_ value: String?) throws -> String {
        guard let value, value.range(of: #"^[A-Z0-9]{10}\.com\.everettjf\.scriptwidget\.services$"#, options: .regularExpression) != nil else {
            throw ScriptWidgetServiceError.invalidConfiguration
        }
        return value
    }

    static func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            throw ScriptWidgetServiceError.locked
        }
        throw ScriptWidgetServiceError.storageUnavailable
    }

    func read(_ account: String) throws -> Data? {
        var selected = try query(account)
        selected[kSecReturnData as String] = true
        selected[kSecMatchLimit as String] = kSecMatchLimitOne
        let authentication = LAContext(); authentication.interactionNotAllowed = true
        selected[kSecUseAuthenticationContext as String] = authentication
        var result: CFTypeRef?
        let status = SecItemCopyMatching(selected as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try Self.check(status)
        guard let data = result as? Data, data.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidCredential }
        return data
    }

    func write(_ data: Data, account: String) throws {
        guard data.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidCredential }
        let selected = try query(account)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(selected as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let inserted = SecItemAdd(selected.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary, nil)
            if inserted == errSecDuplicateItem {
                try Self.check(SecItemUpdate(selected as CFDictionary, attributes as CFDictionary))
            } else { try Self.check(inserted) }
        } else { try Self.check(status) }
    }

    func remove(_ account: String) throws {
        let status = SecItemDelete(try query(account) as CFDictionary)
        if status != errSecItemNotFound { try Self.check(status) }
    }
}

struct ScriptWidgetServiceCredentialVault {
    private let keychain: any ScriptWidgetServiceKeychainAccess

    init(keychain: any ScriptWidgetServiceKeychainAccess = ScriptWidgetServiceSystemKeychain()) { self.keychain = keychain }

    private func key(_ service: ScriptWidgetService, _ accountID: UUID) -> String {
        service.rawValue + ":" + accountID.uuidString.lowercased()
    }

    func read(service: ScriptWidgetService, accountID: UUID, revision: UUID) throws -> ScriptWidgetServiceCredential? {
        guard let data = try keychain.read(key(service, accountID)) else { return nil }
        let credential = try ScriptWidgetServiceCredential.decode(data, accountID: accountID, service: service)
        guard credential.revision == revision else { throw ScriptWidgetServiceError.invalidCredential }
        return credential
    }

    func write(_ credential: ScriptWidgetServiceCredential) throws {
        try keychain.write(credential.encoded(), account: key(credential.service, credential.accountID))
    }

    func readPolicy(service: ScriptWidgetService, accountID: UUID) throws -> ScriptWidgetServiceAccessPolicy? {
        guard let data = try keychain.read("policy:" + key(service, accountID)) else { return nil }
        return try ScriptWidgetServiceAccessPolicy.decode(data, accountID: accountID, service: service)
    }

    func writePolicy(_ policy: ScriptWidgetServiceAccessPolicy) throws {
        try keychain.write(policy.encoded(), account: "policy:" + key(policy.service, policy.accountID))
    }

    func removePolicy(service: ScriptWidgetService, accountID: UUID) throws {
        try keychain.remove("policy:" + key(service, accountID))
    }

    func remove(service: ScriptWidgetService, accountID: UUID) throws {
        try keychain.remove(key(service, accountID))
    }
}
