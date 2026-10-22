import Foundation
import CryptoKit
import Security
import CoreFoundation

// Native-only service credentials. These types must never be JSExport objects,
// package metadata, prompt context, app-group snapshots or diagnostic payloads.
enum ScriptWidgetService: String, Codable, CaseIterable, Sendable {
    case github, spotify

    var apiHost: String { self == .github ? "api.github.com" : "api.spotify.com" }
    var supportedScopes: Set<String> {
        self == .github ? [] : ["user-read-private", "user-read-playback-state", "user-modify-playback-state"]
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
              service != .github || (refreshToken == nil && oauthClientID == nil && scopes.isEmpty),
              service != .spotify || (refreshToken != nil && oauthClientID.map(ScriptWidgetSpotifyAuthorization.validClientID) == true && expiresAt != nil && expiresAt!.timeIntervalSince(issuedAt) <= 86400) else { throw ScriptWidgetServiceError.invalidCredential }
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

/// An authorization session is deliberately a reference type: copying a value
/// must not make its callback redeemable twice. It exists only in app memory.
final class ScriptWidgetSpotifyAuthorization: CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {
    static let callbackScheme = "scriptwidget-spotify-auth"
    static let redirectURI = "scriptwidget-spotify-auth://oauth/spotify/callback"
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    static let readScopes: Set<String> = ["user-read-private", "user-read-playback-state"]
    private let lock = NSLock()
    fileprivate let clientID: String
    private let verifier: String
    private let state: String
    private let createdAt: Date
    let requestedScopes: Set<String>
    private var consumed = false

    var description: String { "<redacted pending service authorization>" }
    var debugDescription: String { description }

    init(clientID: String, playbackControl: Bool, now: Date = Date(), random: (Int) throws -> [UInt8] = secureRandom) throws {
        guard Self.validClientID(clientID), now.timeIntervalSince1970.isFinite else { throw ScriptWidgetServiceError.invalidConfiguration }
        self.clientID = clientID; createdAt = now
        let verifierBytes = try random(64), stateBytes = try random(32)
        guard verifierBytes.count == 64, stateBytes.count == 32 else { throw ScriptWidgetServiceError.authorizationFailed }
        verifier = Self.base64URL(Data(verifierBytes)); state = Self.base64URL(Data(stateBytes))
        requestedScopes = Self.readScopes.union(playbackControl ? ["user-modify-playback-state"] : [])
    }

    static func validClientID(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return (8...128).contains(value.utf8.count) && value.unicodeScalars.allSatisfy(allowed.contains)
    }

    static func secureRandom(_ count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { throw ScriptWidgetServiceError.authorizationFailed }
        return bytes
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    var authorizationURL: URL {
        var parts = URLComponents(string: "https://accounts.spotify.com/authorize")!
        parts.queryItems = [URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI), URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"), URLQueryItem(name: "code_challenge", value: Self.challenge(verifier)),
            URLQueryItem(name: "scope", value: requestedScopes.sorted().joined(separator: " "))]
        return parts.url!
    }

    private static func equalState(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8), b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }

    func tokenRequest(callback: URL, now: Date = Date()) throws -> URLRequest {
        lock.lock(); defer { lock.unlock() }
        guard !consumed else { throw ScriptWidgetServiceError.consumedAuthorization }
        guard now >= createdAt, now.timeIntervalSince(createdAt) <= 300 else { consumed = true; throw ScriptWidgetServiceError.expiredAuthorization }
        guard callback.absoluteString.utf8.count <= 8192, let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              parts.scheme == Self.callbackScheme, parts.host == "oauth", parts.percentEncodedPath == "/spotify/callback",
              parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil,
              let items = parts.queryItems, items.count <= 4,
              Set(items.map(\.name)).count == items.count,
              Set(items.map(\.name)).isSubset(of: ["code", "state", "error", "error_description"]),
              let receivedState = items.first(where: { $0.name == "state" })?.value,
              Self.equalState(receivedState, state) else { throw ScriptWidgetServiceError.invalidCallback }
        let code = items.first(where: { $0.name == "code" })?.value
        let error = items.first(where: { $0.name == "error" })?.value
        guard (code == nil) != (error == nil) else { throw ScriptWidgetServiceError.invalidCallback }
        consumed = true
        if let error { throw error == "access_denied" ? ScriptWidgetServiceError.cancelled : .authorizationFailed }
        guard let code, ScriptWidgetServiceCredential.validSecret(code) else { throw ScriptWidgetServiceError.invalidCallback }
        return Self.formRequest(["grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirectURI, "client_id": clientID, "code_verifier": verifier])
    }

    static func refreshRequest(clientID: String, credential: ScriptWidgetServiceCredential) throws -> URLRequest {
        try credential.validate()
        guard validClientID(clientID), credential.service == .spotify, credential.oauthClientID == clientID,
              let token = credential.refreshToken else { throw ScriptWidgetServiceError.invalidCredential }
        return formRequest(["grant_type": "refresh_token", "refresh_token": token, "client_id": clientID])
    }

    private static func formRequest(_ values: [String: String]) -> URLRequest {
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let form = values.keys.sorted().map { key in key + "=" + values[key]!.addingPercentEncoding(withAllowedCharacters: unreserved)! }.joined(separator: "&")
        var request = URLRequest(url: tokenURL); request.httpMethod = "POST"; request.httpBody = Data(form.utf8)
        request.timeoutInterval = 15; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func credential(response: Data, accountID: UUID, clientID: String, requestedScopes: Set<String>, previous: ScriptWidgetServiceCredential? = nil, now: Date = Date()) throws -> ScriptWidgetServiceCredential {
        guard validClientID(clientID), requestedScopes.isSubset(of: ScriptWidgetService.spotify.supportedScopes), Self.readScopes.isSubset(of: requestedScopes),
              now.timeIntervalSince1970.isFinite, response.count <= 16 * 1024 else { throw ScriptWidgetServiceError.invalidCredential }
        if let previous { try previous.validate(); guard previous.accountID == accountID, previous.service == .spotify, previous.oauthClientID == clientID, previous.scopes == requestedScopes else { throw ScriptWidgetServiceError.invalidCredential } }
        guard let object = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              Set(object.keys).isSubset(of: ["access_token", "token_type", "expires_in", "refresh_token", "scope"]),
              let access = object["access_token"] as? String, let type = object["token_type"] as? String, type.lowercased() == "bearer",
              let expires = object["expires_in"] as? NSNumber, CFGetTypeID(expires) != CFBooleanGetTypeID(),
              expires.doubleValue.isFinite, expires.doubleValue.rounded() == expires.doubleValue, (1...86400).contains(expires.doubleValue) else { throw ScriptWidgetServiceError.invalidCredential }
        let scopes: Set<String>
        if let text = object["scope"] as? String {
            guard text.utf8.count <= 1024, text.unicodeScalars.allSatisfy({ (0x20...0x7e).contains($0.value) }) else { throw ScriptWidgetServiceError.invalidCredential }
            let returned = Set(text.split(separator: " ").map(String.init))
            guard requestedScopes.isSubset(of: returned) else { throw ScriptWidgetServiceError.permissionDenied }
            scopes = returned.intersection(requestedScopes)
        } else {
            guard object["scope"] == nil, let previous else { throw ScriptWidgetServiceError.invalidCredential }
            scopes = previous.scopes
        }
        let refresh: String?
        if let raw = object["refresh_token"] { guard let token = raw as? String else { throw ScriptWidgetServiceError.invalidCredential }; refresh = token }
        else { refresh = previous?.refreshToken }
        guard refresh != nil else { throw ScriptWidgetServiceError.invalidCredential }
        let credential = ScriptWidgetServiceCredential(formatVersion: 1, accountID: accountID, service: .spotify, revision: UUID(), accessToken: access, refreshToken: refresh, oauthClientID: clientID, issuedAt: now, expiresAt: now.addingTimeInterval(expires.doubleValue), scopes: scopes)
        try credential.validate(); return credential
    }
}

/// Native-only exchange of PKCE codes and refresh tokens. No arbitrary URL,
/// callback payload or provider response is forwarded to scripts or diagnostics.
final class ScriptWidgetSpotifyTokenClient {
    private let transport: any ScriptWidgetServiceHTTPTransport
    private let now: () -> Date
    init(transport: any ScriptWidgetServiceHTTPTransport = ScriptWidgetServiceURLTransport(maximumResponseBytes: 16 * 1024),
         now: @escaping () -> Date = Date.init) {
        self.transport = transport; self.now = now
    }

    @discardableResult func exchange(_ session: ScriptWidgetSpotifyAuthorization, callback: URL, accountID: UUID,
        completion: @escaping (Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        do {
            let request = try session.tokenRequest(callback: callback, now: now())
            return send(request, accountID: accountID, clientID: session.clientID, scopes: session.requestedScopes, completion: completion)
        } catch { completion(.failure(error as? ScriptWidgetServiceError ?? .authorizationFailed)); return .init({}) }
    }

    @discardableResult func refresh(_ credential: ScriptWidgetServiceCredential,
        completion: @escaping (Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        do {
            guard let clientID = credential.oauthClientID else { throw ScriptWidgetServiceError.invalidCredential }
            let request = try ScriptWidgetSpotifyAuthorization.refreshRequest(clientID: clientID, credential: credential)
            return send(request, accountID: credential.accountID, clientID: clientID, scopes: credential.scopes, previous: credential, completion: completion)
        } catch { completion(.failure(error as? ScriptWidgetServiceError ?? .invalidCredential)); return .init({}) }
    }

    private func send(_ request: URLRequest, accountID: UUID, clientID: String, scopes: Set<String>, previous: ScriptWidgetServiceCredential? = nil,
        completion: @escaping (Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        let delivery = Delivery(completion)
        let handle = transport.send(request) { [now] result in
            let decoded = result.flatMap { response -> Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError> in
                do {
                    guard response.status == 200 else { throw ScriptWidgetServiceError.authorizationFailed }
                    return .success(try ScriptWidgetSpotifyAuthorization.credential(response: response.body, accountID: accountID,
                        clientID: clientID, requestedScopes: scopes, previous: previous, now: now()))
                } catch { return .failure(error as? ScriptWidgetServiceError ?? .invalidCredential) }
            }
            delivery.finish(decoded)
        }
        delivery.attach(handle)
        return .init { delivery.cancel() }
    }

    private final class Delivery: @unchecked Sendable {
        private let lock = NSLock()
        private var completion: ((Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) -> Void)?
        private var request: ScriptWidgetServiceRequestHandle?
        init(_ completion: @escaping (Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) -> Void) { self.completion = completion }
        func attach(_ handle: ScriptWidgetServiceRequestHandle) {
            lock.lock(); let finished = completion == nil
            if !finished { request = handle }; lock.unlock()
            if finished { handle.cancel() }
        }
        func finish(_ result: Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>) {
            lock.lock(); let callback = completion; completion = nil; request = nil; lock.unlock()
            callback?(result)
        }
        func cancel() {
            lock.lock(); let callback = completion, pending = request; completion = nil; request = nil; lock.unlock()
            pending?.cancel(); callback?(.failure(.cancelled))
        }
    }
}
