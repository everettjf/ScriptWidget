import Foundation
import CoreFoundation
import CryptoKit

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
        label = [profile.username, profile.displayName].compactMap { $0 }.first {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? profile.subject
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

    func refreshing(_ updated: ScriptWidgetServiceCredential) throws -> Self {
        try updated.validate()
        guard credential.service == .spotify, updated.service == credential.service, updated.accountID == credential.accountID,
              updated.oauthClientID == credential.oauthClientID, updated.scopes == credential.scopes,
              updated.revision != credential.revision, updated.issuedAt >= credential.issuedAt else { throw ScriptWidgetServiceError.invalidCredential }
        return try .init(credential: updated, policy: policy, subject: subject, label: label)
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

    /// An in-flight refresh cannot resurrect a disconnected account or overwrite
    /// a newer credential/grant. The network request never holds this lock.
    @discardableResult func refreshCredential(_ updated: ScriptWidgetServiceCredential,
                                             expected: ScriptWidgetServiceConnection) throws -> ScriptWidgetServiceConnection {
        try transaction {
            guard let current = try load(expected.credential.service) else { throw ScriptWidgetServiceError.notConnected }
            guard current.policy.connectionID == expected.policy.connectionID,
                  current.revision == expected.revision, current.credential.accountID == expected.credential.accountID,
                  current.credential.revision == expected.credential.revision else { throw ScriptWidgetServiceError.conflict }
            let changed = try current.refreshing(updated)
            try keychain.write(changed.encoded(), account: key(updated.service))
            return changed
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

/// Native-only write receipts contain no account label, provider payload or
/// credentials. Uncertain attempts are never evicted or automatically retried.
struct ScriptWidgetServiceWriteReceipt: Equatable, CustomStringConvertible {
    let service: ScriptWidgetService
    let requestID: UUID
    let operation: ScriptWidgetServiceOperation
    let replayed: Bool
    var description: String { "<native service action receipt>" }
}
struct ScriptWidgetServiceWritePermit: CustomStringConvertible {
    let service: ScriptWidgetService
    let requestID: UUID
    fileprivate let fingerprint: String
    fileprivate let nonce: UUID
    var description: String { "<private service action permit>" }
}
enum ScriptWidgetServiceWritePreparation {
    case dispatch(ScriptWidgetServiceWritePermit)
    case replay(ScriptWidgetServiceWriteReceipt)
}
enum ScriptWidgetServiceWriteOutcome: String, Codable {
    case prepared, accepted, permission, expired, rateLimited
    var failure: ScriptWidgetServiceError? {
        switch self {
        case .prepared: .outcomeUnknown
        case .accepted: nil
        case .permission: .permissionDenied
        case .expired: .expiredAuthorization
        case .rateLimited: .rateLimited
        }
    }
}
extension ScriptWidgetServiceConnections {
    static let maximumWriteEntries = 512
    static let maximumWriteBytes = 256 * 1024
    static let writeRetention: TimeInterval = 7 * 86_400
    private struct WriteEntry: Codable {
        let requestID: UUID
        let fingerprint: String
        let nonce: UUID
        let createdAt: Double
        var outcome: ScriptWidgetServiceWriteOutcome
    }
    private struct WriteLedger: Codable { let formatVersion: Int; var entries: [WriteEntry] }
    private func writeKey(_ service: ScriptWidgetService) -> String { "writes:" + service.rawValue }
    private func writeFingerprint(_ plan: ScriptWidgetServiceRequestPlan) -> String {
        let text = ["1",plan.operation.service.rawValue,plan.accountID.uuidString,plan.connectionID.uuidString,plan.ownerID.uuidString,plan.operation.rawValue].joined(separator:"|")
        return SHA256.hash(data:Data(text.utf8)).map { String(format:"%02x",$0) }.joined()
    }
    private func validateWriteAuthority(_ plan: ScriptWidgetServiceRequestPlan, expected: ScriptWidgetServiceConnection) throws {
        guard plan.operation.isWrite, plan.requestID != nil, plan.accountID == expected.credential.accountID,
              plan.operation.service == expected.credential.service, plan.connectionID == expected.policy.connectionID, plan.policyRevision == expected.revision,
              plan.request.url?.absoluteString == "https://" + plan.operation.service.apiHost + plan.operation.path,
              plan.request.httpMethod == plan.operation.method, plan.request.httpBody == nil, plan.request.httpBodyStream == nil,
              plan.request.value(forHTTPHeaderField:"Authorization") == "Bearer " + expected.credential.accessToken else { throw ScriptWidgetServiceError.permissionDenied }
        guard let current = try load(expected.credential.service) else { throw ScriptWidgetServiceError.notConnected }
        guard current.policy.connectionID == expected.policy.connectionID, current.credential.accountID == expected.credential.accountID,
              current.credential.revision == expected.credential.revision, current.revision == expected.revision,
              current.policy.grants.contains(where: { $0.ownerID == plan.ownerID && $0.operations.contains(plan.operation) }),
              plan.operation.scope.map({ current.credential.scopes.contains($0) }) ?? true else { throw ScriptWidgetServiceError.permissionDenied }
    }
    private func readWrites(_ service: ScriptWidgetService) throws -> WriteLedger {
        guard let bytes = try keychain.read(writeKey(service)) else { return .init(formatVersion:1,entries:[]) }
        guard bytes.count <= Self.maximumWriteBytes,
              let decoded = try? JSONDecoder().decode(WriteLedger.self,from:bytes), decoded.formatVersion == 1,
              decoded.entries.count <= Self.maximumWriteEntries, Set(decoded.entries.map(\.requestID)).count == decoded.entries.count,
              let original = try? JSONSerialization.jsonObject(with:bytes),
              let normalized = try? JSONSerialization.jsonObject(with:JSONEncoder().encode(decoded)),
              try JSONSerialization.data(withJSONObject:original,options:.sortedKeys) == JSONSerialization.data(withJSONObject:normalized,options:.sortedKeys),
              decoded.entries.allSatisfy({ $0.fingerprint.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil && $0.createdAt.isFinite && $0.createdAt >= 0 }) else { throw ScriptWidgetServiceError.writeHistoryInvalid }
        return decoded
    }
    private func saveWrites(_ ledger: WriteLedger, service: ScriptWidgetService) throws {
        let bytes = try JSONEncoder().encode(ledger)
        guard bytes.count <= Self.maximumWriteBytes else { throw ScriptWidgetServiceError.writeHistoryFull }
        try keychain.write(bytes,account:writeKey(service))
    }
    func prepareWrite(_ plan: ScriptWidgetServiceRequestPlan, expected: ScriptWidgetServiceConnection, now: Date = Date()) throws -> ScriptWidgetServiceWritePreparation {
        try transaction {
            try validateWriteAuthority(plan,expected:expected)
            guard now.timeIntervalSince1970.isFinite, now.timeIntervalSince1970 >= 0 else { throw ScriptWidgetServiceError.invalidConfiguration }
            let service = plan.operation.service, requestID = plan.requestID!, fingerprint = writeFingerprint(plan)
            var ledger = try readWrites(service)
            ledger.entries.removeAll { $0.outcome != .prepared && now.timeIntervalSince1970 - $0.createdAt > Self.writeRetention }
            if let prior = ledger.entries.first(where: { $0.requestID == requestID }) {
                guard prior.fingerprint == fingerprint else { throw ScriptWidgetServiceError.requestConflict }
                if let failure = prior.outcome.failure { throw failure }
                return .replay(.init(service:service,requestID:requestID,operation:plan.operation,replayed:true))
            }
            guard expected.credential.expiresAt.map({ $0 > now.addingTimeInterval(15) }) ?? true else { throw ScriptWidgetServiceError.expiredAuthorization }
            guard ledger.entries.count < Self.maximumWriteEntries else { throw ScriptWidgetServiceError.writeHistoryFull }
            let nonce = UUID()
            ledger.entries.append(.init(requestID:requestID,fingerprint:fingerprint,nonce:nonce,createdAt:now.timeIntervalSince1970,outcome:.prepared))
            try saveWrites(ledger,service:service)
            return .dispatch(.init(service:service,requestID:requestID,fingerprint:fingerprint,nonce:nonce))
        }
    }
    func completeWrite(_ permit: ScriptWidgetServiceWritePermit, plan: ScriptWidgetServiceRequestPlan, expected: ScriptWidgetServiceConnection,
                       outcome: ScriptWidgetServiceWriteOutcome) throws -> ScriptWidgetServiceWriteReceipt {
        try transaction {
            try validateWriteAuthority(plan,expected:expected)
            guard outcome != .prepared, permit.service == plan.operation.service, permit.requestID == plan.requestID,
                  permit.fingerprint == writeFingerprint(plan) else { throw ScriptWidgetServiceError.requestConflict }
            var ledger = try readWrites(permit.service)
            guard let index = ledger.entries.firstIndex(where: { $0.requestID == permit.requestID }),
                  ledger.entries[index].nonce == permit.nonce, ledger.entries[index].fingerprint == permit.fingerprint else { throw ScriptWidgetServiceError.outcomeUnknown }
            guard ledger.entries[index].outcome == .prepared || ledger.entries[index].outcome == outcome else { throw ScriptWidgetServiceError.requestConflict }
            ledger.entries[index].outcome = outcome
            do { try saveWrites(ledger,service:permit.service) } catch { throw ScriptWidgetServiceError.outcomeUnknown }
            if let failure = outcome.failure { throw failure }
            return .init(service:permit.service,requestID:permit.requestID,operation:plan.operation,replayed:false)
        }
    }
}
