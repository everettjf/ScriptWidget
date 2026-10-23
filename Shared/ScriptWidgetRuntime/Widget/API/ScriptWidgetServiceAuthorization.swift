import Foundation
import CoreFoundation

// Native-only service credentials. These types must never be JSExport objects,
// package metadata, prompt context, app-group snapshots or diagnostic payloads.
enum ScriptWidgetService: String, Codable, CaseIterable, Sendable {
    case github

    var apiHost: String { "api.github.com" }
    var supportedScopes: Set<String> {
        []
    }
}

enum ScriptWidgetServiceError: LocalizedError, Equatable {
    case invalidConfiguration, invalidCallback, expiredAuthorization, consumedAuthorization
    case cancelled, authorizationFailed, invalidCredential, locked, storageUnavailable
    case notConnected, permissionDenied, unsupportedOperation, rateLimited, unavailable, conflict, networkLimit

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "[service_configuration] Review the native service settings."
        case .invalidCallback: "[service_callback] The authorization callback could not be verified."
        case .expiredAuthorization: "[service_expired] Start a new service authorization."
        case .consumedAuthorization: "[service_replay] This authorization has already completed."
        case .cancelled: "[service_cancelled] Authorization was cancelled."
        case .authorizationFailed: "[service_authorization] Service authorization failed."
        case .invalidCredential: "[service_credential] The service credential is invalid. Reconnect in the app."
        case .locked: "[service_locked] Unlock this device to use the connected service."
        case .storageUnavailable: "[service_storage] Secure credential storage is unavailable."
        case .conflict: "[service_conflict] Service settings changed. Reload before saving."
        case .notConnected: "[service_not_connected] Connect a service in the app."
        case .permissionDenied: "[service_permission] Allow this service operation in the app."
        case .unsupportedOperation: "[service_operation] This service operation is unsupported."
        case .networkLimit: "[network_limit] Too many concurrent or total network requests."
        case .rateLimited: "[service_rate_limit] The service is rate limited. Try again later."
        case .unavailable: "[service_unavailable] The service is currently unavailable."
        }
    }
}

struct ScriptWidgetServiceCredential: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let formatVersion: Int
    let accountID: UUID
    let service: ScriptWidgetService
    let revision: UUID
    let accessToken: String
    let refreshToken: String?
    let oauthClientID: String?
    let issuedAt: Date
    let expiresAt: Date?
    let scopes: Set<String>

    var description: String { "<redacted service credential>" }
    var debugDescription: String { description }

    static func validSecret(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 4096 && value.unicodeScalars.allSatisfy { (0x21...0x7e).contains($0.value) }
    }

    func validate() throws {
        guard formatVersion == 1, Self.validSecret(accessToken),
              refreshToken.map(Self.validSecret) ?? true,
              issuedAt.timeIntervalSince1970.isFinite, issuedAt.timeIntervalSince1970 >= 0,
              expiresAt.map({ $0.timeIntervalSince1970.isFinite && $0 > issuedAt }) ?? true,
              scopes.isSubset(of: service.supportedScopes),
              refreshToken == nil, oauthClientID == nil, scopes.isEmpty else { throw ScriptWidgetServiceError.invalidCredential }
        // Bearer values are inserted into a header by the native proxy only.
        let bearer = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~+/=")
        guard accessToken.unicodeScalars.allSatisfy(bearer.contains) else { throw ScriptWidgetServiceError.invalidCredential }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970; encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidCredential }
        return data
    }

    static func decode(_ data: Data, accountID: UUID, service: ScriptWidgetService) throws -> Self {
        do {
            guard data.count <= 16 * 1024,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Set(object.keys).isSubset(of: ["formatVersion", "accountID", "service", "revision", "accessToken", "refreshToken", "oauthClientID", "issuedAt", "expiresAt", "scopes"]) else { throw ScriptWidgetServiceError.invalidCredential }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
            let value = try decoder.decode(Self.self, from: data)
            guard value.accountID == accountID, value.service == service else { throw ScriptWidgetServiceError.invalidCredential }
            try value.validate(); return value
        } catch { throw ScriptWidgetServiceError.invalidCredential }
    }
}
