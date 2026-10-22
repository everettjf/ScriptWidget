import Foundation

enum ScriptWidgetServiceOperation: String, Codable, CaseIterable, Sendable {
    case githubProfile = "github.profile"

    var service: ScriptWidgetService { .github }
    var isWrite: Bool { false }
    var scope: String? { nil }
    var method: String { "GET" }
    var path: String { "/user" }
}

struct ScriptWidgetServiceOwnerGrant: Codable, Sendable {
    let ownerID: UUID
    let operations: Set<ScriptWidgetServiceOperation>
}

/// Authorization authority stays in Keychain. An app-group status/cache file
/// cannot create a grant or widen a widget's permitted service operations.
struct ScriptWidgetServiceAccessPolicy: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let formatVersion: Int
    let accountID: UUID
    let service: ScriptWidgetService
    let connectionID: UUID
    let revision: UUID
    let active: Bool
    let grants: [ScriptWidgetServiceOwnerGrant]

    var description: String { "<redacted service access policy>" }
    var debugDescription: String { description }

    static func connected(accountID: UUID, service: ScriptWidgetService) -> Self {
        .init(formatVersion: 1, accountID: accountID, service: service, connectionID: UUID(), revision: UUID(), active: true, grants: [])
    }

    func validate() throws {
        guard formatVersion == 1, grants.count <= 32, Set(grants.map(\.ownerID)).count == grants.count,
              grants.allSatisfy({ !$0.operations.isEmpty && $0.operations.allSatisfy { $0.service == service } }) else { throw ScriptWidgetServiceError.invalidConfiguration }
    }

    func updatingGrant(ownerID: UUID, operations: Set<ScriptWidgetServiceOperation>, expectedRevision: UUID) throws -> Self {
        try validate()
        guard active else { throw ScriptWidgetServiceError.notConnected }
        guard expectedRevision == revision else { throw ScriptWidgetServiceError.conflict }
        var changed = grants.filter { $0.ownerID != ownerID }
        if !operations.isEmpty { changed.append(.init(ownerID: ownerID, operations: operations)) }
        let result = Self(formatVersion: formatVersion, accountID: accountID, service: service, connectionID: connectionID,
            revision: UUID(), active: active, grants: changed.sorted { $0.ownerID.uuidString < $1.ownerID.uuidString })
        try result.validate(); return result
    }

    func revoked() -> Self {
        .init(formatVersion: 1, accountID: accountID, service: service, connectionID: connectionID, revision: UUID(), active: false, grants: [])
    }

    func encoded() throws -> Data {
        try validate()
        let data = try JSONEncoder().encode(self)
        guard data.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidConfiguration }
        return data
    }

    static func decode(_ data: Data, accountID: UUID, service: ScriptWidgetService) throws -> Self {
        do {
            guard data.count <= 16 * 1024, let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(object.keys) == ["formatVersion", "accountID", "service", "connectionID", "revision", "active", "grants"],
                  let grants = object["grants"] as? [[String: Any]], grants.count <= 32,
                  grants.allSatisfy({ Set($0.keys) == ["ownerID", "operations"] }) else { throw ScriptWidgetServiceError.invalidConfiguration }
            let result = try JSONDecoder().decode(Self.self, from: data)
            guard result.accountID == accountID, result.service == service else { throw ScriptWidgetServiceError.invalidConfiguration }
            try result.validate(); return result
        } catch { throw ScriptWidgetServiceError.invalidConfiguration }
    }
}

/// Fixed native operation plans, not arbitrary authenticated URLs or headers.
/// The caller must obtain owner/context/permission facts from native execution
/// state. Neither this type nor its URLRequest is exported to JavaScript.
struct ScriptWidgetServiceRequestPlan: CustomStringConvertible, CustomDebugStringConvertible {
    let request: URLRequest
    let operation: ScriptWidgetServiceOperation
    let requestID: UUID?
    let ownerID: UUID
    let accountID: UUID
    let connectionID: UUID
    let policyRevision: UUID
    var description: String { "<redacted native service request>" }
    var debugDescription: String { description }

    init(operation: ScriptWidgetServiceOperation, credential: ScriptWidgetServiceCredential, policy: ScriptWidgetServiceAccessPolicy,
         ownerID: UUID, expectedConnectionID: UUID, isUserInitiatedAction: Bool, requestID: UUID? = nil,
         hasNetworkPermission: Bool, allowsHost: (String) -> Bool, now: Date = Date()) throws {
        try credential.validate(); try policy.validate()
        guard credential.accountID == policy.accountID, credential.service == policy.service, operation.service == policy.service,
              policy.connectionID == expectedConnectionID else { throw ScriptWidgetServiceError.invalidCredential }
        guard policy.active else { throw ScriptWidgetServiceError.notConnected }
        guard policy.grants.contains(where: { $0.ownerID == ownerID && $0.operations.contains(operation) }),
              operation.scope.map({ credential.scopes.contains($0) }) ?? true else { throw ScriptWidgetServiceError.permissionDenied }
        guard !operation.isWrite || (isUserInitiatedAction && requestID != nil) else { throw ScriptWidgetServiceError.permissionDenied }
        guard hasNetworkPermission, allowsHost(operation.service.apiHost) else { throw ScriptWidgetServiceError.permissionDenied }
        guard now.timeIntervalSince1970.isFinite, credential.issuedAt <= now.addingTimeInterval(60),
              credential.expiresAt.map({ $0 > now.addingTimeInterval(15) }) ?? true else { throw ScriptWidgetServiceError.expiredAuthorization }
        var request = URLRequest(url: URL(string: "https://" + operation.service.apiHost + operation.path)!)
        request.httpMethod = operation.method; request.timeoutInterval = 5; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("Bearer " + credential.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue("ScriptWidget", forHTTPHeaderField: "User-Agent")
        request.setValue(operation.service == .github ? "application/vnd.github+json" : "application/json", forHTTPHeaderField: "Accept")
        if operation.service == .github { request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version") }
        self.request = request; self.operation = operation; self.requestID = requestID; self.ownerID = ownerID
        accountID = policy.accountID; connectionID = policy.connectionID; policyRevision = policy.revision
    }
}
