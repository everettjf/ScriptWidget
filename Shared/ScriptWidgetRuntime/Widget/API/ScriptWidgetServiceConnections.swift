import Foundation
import CoreFoundation

/// One atomic Keychain item per service. Credential and grants cannot describe
/// different connections after interruption. Reconnecting creates a fresh
/// account/connection and deliberately does not inherit the old owner's grants.
struct ScriptWidgetServiceConnection: CustomStringConvertible, CustomDebugStringConvertible {
    let credential: ScriptWidgetServiceCredential
    let policy: ScriptWidgetServiceAccessPolicy
    let subject: String
    let label: String
    var revision: UUID { policy.revision }
    var description: String { "<redacted native service connection>" }
    var debugDescription: String { description }

    init(credential: ScriptWidgetServiceCredential, profile: ScriptWidgetServiceProfile) throws {
        guard profile.service == credential.service else { throw ScriptWidgetServiceError.invalidCredential }
        self.credential = credential
        policy = .connected(accountID: credential.accountID, service: credential.service)
        subject = profile.subject
        label = profile.username ?? profile.displayName ?? profile.subject
        try validate()
    }

    private init(credential: ScriptWidgetServiceCredential, policy: ScriptWidgetServiceAccessPolicy, subject: String, label: String) throws {
        self.credential = credential; self.policy = policy; self.subject = subject; self.label = label
        try validate()
    }

    private func validate() throws {
        try credential.validate(); try policy.validate()
        guard credential.accountID == policy.accountID, credential.service == policy.service, policy.active,
              !subject.isEmpty, subject.utf8.count <= 128, !label.isEmpty, label.utf8.count <= 256,
              ![subject, label].contains(where: { value in
                  value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) ||
                  [credential.accessToken, credential.refreshToken].compactMap({ $0 }).contains(where: value.contains)
              }) else { throw ScriptWidgetServiceError.invalidCredential }
    }

    func updatingGrant(ownerID: UUID, operations: Set<ScriptWidgetServiceOperation>, expectedRevision: UUID) throws -> Self {
        try .init(credential: credential, policy: policy.updatingGrant(ownerID: ownerID, operations: operations, expectedRevision: expectedRevision), subject: subject, label: label)
    }

    func encoded() throws -> Data {
        try validate()
        let bytes = try JSONSerialization.data(withJSONObject: ["formatVersion": 1,
            "credential": JSONSerialization.jsonObject(with: credential.encoded()),
            "policy": JSONSerialization.jsonObject(with: policy.encoded()), "subject": subject, "label": label], options: [.sortedKeys])
        guard bytes.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidCredential }
        return bytes
    }

    static func decode(_ data: Data, service: ScriptWidgetService) throws -> Self {
        do {
            guard data.count <= 16 * 1024, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(object.keys) == ["formatVersion", "credential", "policy", "subject", "label"],
                  let version = object["formatVersion"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version == 1,
                  let credentialObject = object["credential"] as? [String: Any],
                  let account = credentialObject["accountID"] as? String, let accountID = UUID(uuidString: account),
                  let policyObject = object["policy"] as? [String: Any],
                  let subject = object["subject"] as? String, let label = object["label"] as? String else { throw ScriptWidgetServiceError.invalidCredential }
            return try .init(credential: .decode(JSONSerialization.data(withJSONObject: credentialObject), accountID: accountID, service: service),
                policy: .decode(JSONSerialization.data(withJSONObject: policyObject), accountID: accountID, service: service), subject: subject, label: label)
        } catch { throw ScriptWidgetServiceError.invalidCredential }
    }
}

/// The supplied coordinator must serialize all app/extension transactions. It
/// never spans a network request. Production supplies the app-group file lock;
/// tests supply a private lock and memory Keychain, without touching accounts.
final class ScriptWidgetServiceConnections {
    private let keychain: any ScriptWidgetServiceKeychainAccess
    private let coordinate: (() throws -> Void) throws -> Void
    init(keychain: any ScriptWidgetServiceKeychainAccess, coordinate: @escaping (() throws -> Void) throws -> Void) {
        self.keychain = keychain; self.coordinate = coordinate
    }
    private func key(_ service: ScriptWidgetService) -> String { "connection:" + service.rawValue }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        try coordinate { result = Result(catching: body) }
        guard let result else { throw ScriptWidgetServiceError.storageUnavailable }
        return try result.get()
    }
    private func load(_ service: ScriptWidgetService) throws -> ScriptWidgetServiceConnection? {
        guard let data = try keychain.read(key(service)) else { return nil }
        return try .decode(data, service: service)
    }
    func connection(_ service: ScriptWidgetService) throws -> ScriptWidgetServiceConnection? { try transaction { try load(service) } }

    @discardableResult func connect(_ credential: ScriptWidgetServiceCredential, verifiedProfile: ScriptWidgetServiceProfile,
                                   expectedRevision: UUID?) throws -> ScriptWidgetServiceConnection {
        try transaction {
            let current = try load(credential.service)
            guard current?.revision == expectedRevision else { throw ScriptWidgetServiceError.conflict }
            let changed = try ScriptWidgetServiceConnection(credential: credential, profile: verifiedProfile)
            guard current?.credential.accountID != credential.accountID else { throw ScriptWidgetServiceError.conflict }
            try keychain.write(changed.encoded(), account: key(credential.service))
            return changed
        }
    }

    @discardableResult func setGrant(service: ScriptWidgetService, ownerID: UUID, operations: Set<ScriptWidgetServiceOperation>,
                                    expectedRevision: UUID) throws -> ScriptWidgetServiceConnection {
        try transaction {
            guard let current = try load(service) else { throw ScriptWidgetServiceError.notConnected }
            let changed = try current.updatingGrant(ownerID: ownerID, operations: operations, expectedRevision: expectedRevision)
            try keychain.write(changed.encoded(), account: key(service))
            return changed
        }
    }

    func disconnect(_ service: ScriptWidgetService, expectedRevision: UUID) throws {
        try transaction {
            guard let current = try load(service) else { throw ScriptWidgetServiceError.notConnected }
            guard current.revision == expectedRevision else { throw ScriptWidgetServiceError.conflict }
            try keychain.remove(key(service))
        }
    }

    /// Pending results may not survive disconnect/reconnect, token rotation or
    /// grant changes. Runtime callers additionally recheck execution identity.
    func revalidate(_ expected: ScriptWidgetServiceConnection) throws {
        try transaction {
            guard let current = try load(expected.credential.service) else { throw ScriptWidgetServiceError.notConnected }
            guard current.policy.connectionID == expected.policy.connectionID,
                  current.credential.accountID == expected.credential.accountID,
                  current.credential.revision == expected.credential.revision,
                  current.revision == expected.revision else { throw ScriptWidgetServiceError.permissionDenied }
        }
    }
}

#if !SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
extension ScriptWidgetServiceConnections {
    static func live() throws -> ScriptWidgetServiceConnections {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget") else {
            throw ScriptWidgetServiceError.storageUnavailable
        }
        return .init(keychain: ScriptWidgetServiceSystemKeychain(), coordinate: { action in
            guard let result = ScriptWidgetStorageLock.withExclusiveAccess(container: container,
                namespace: "ScriptWidgetServices.Connections.v1", operation: { Result { try action() } }) else { throw ScriptWidgetServiceError.storageUnavailable }
            try result.get()
        })
    }
}
#endif
