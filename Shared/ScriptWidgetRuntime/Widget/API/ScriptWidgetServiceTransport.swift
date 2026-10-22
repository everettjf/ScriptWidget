import Foundation
import CoreFoundation

/// A deliberately small, typed projection. Provider payloads, headers, email,
/// location and credential material never become script values.
struct ScriptWidgetServiceProfile: Codable, Equatable, Sendable {
    let service: ScriptWidgetService
    let subject: String
    let username: String?
    let displayName: String?
    let publicRepositories: Int?
    let privateRepositories: Int?
    let followers: Int?
    let following: Int?
}

struct ScriptWidgetServicePlayback: Codable, Equatable, Sendable {
    let itemType: String
    let itemID: String?
    let title: String?
    let artists: [String]
    let album: String?
    let isPlaying: Bool
    let progressMilliseconds: Int?
    let durationMilliseconds: Int?
    let hasActiveDevice: Bool
    let isRestricted: Bool
}

enum ScriptWidgetServiceResponse: Equatable, Sendable {
    case profile(ScriptWidgetServiceProfile)
    case playback(ScriptWidgetServicePlayback?)
}

/// Injectable transport for native app/runtime tests. The cancellation handle
/// owns no credentials in its printable representation.
struct ScriptWidgetServiceHTTPResponse: CustomStringConvertible, CustomDebugStringConvertible {
    let status: Int
    let body: Data
    var description: String { "<private native service response>" }
    var debugDescription: String { description }
}

protocol ScriptWidgetServiceHTTPTransport {
    @discardableResult func send(_ request: URLRequest,
        completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle
}

final class ScriptWidgetServiceRequestHandle: @unchecked Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    private let lock = NSLock()
    private var action: (() -> Void)?
    init(_ action: @escaping () -> Void) { self.action = action }
    func cancel() { lock.lock(); let saved = action; action = nil; lock.unlock(); saved?() }
    var description: String { "<native service cancellation>" }
    var debugDescription: String { description }
}

/// Each request uses its own ephemeral session and a serial delegate lane.
/// Streaming bounds apply before appending bytes, including chunked bodies.
final class ScriptWidgetServiceURLTransport: ScriptWidgetServiceHTTPTransport {
    static let maximumResponseBytes = 128 * 1024
    private let protocolClasses: [AnyClass]?
    init() { protocolClasses = nil }
    #if DEBUG || SCRIPTWIDGET_SERVICE_STANDALONE_TESTS
    init(protocolClasses: [AnyClass]) { self.protocolClasses = protocolClasses }
    #endif

    @discardableResult func send(_ request: URLRequest,
        completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        let worker = Worker(request: request, completion: completion)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.urlCredentialStorage = nil; configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5; configuration.timeoutIntervalForResource = 6
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        let lane = OperationQueue(); lane.maxConcurrentOperationCount = 1; lane.name = "ScriptWidget.ServiceHTTP"
        let session = URLSession(configuration: configuration, delegate: worker, delegateQueue: lane)
        worker.session = session
        let task = session.dataTask(with: request)
        let handle = ScriptWidgetServiceRequestHandle { task.cancel() }
        task.resume()
        return handle
    }

    private final class Worker: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        let request: URLRequest
        let completion: (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void
        var session: URLSession?
        var body = Data()
        var completed = false
        var status: Int?
        init(request: URLRequest, completion: @escaping (Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) -> Void) {
            self.request = request; self.completion = completion
        }
        func finish(_ result: Result<ScriptWidgetServiceHTTPResponse, ScriptWidgetServiceError>) {
            guard !completed else { return }; completed = true
            body.removeAll(keepingCapacity: false)
            let saved = session; session = nil
            saved?.invalidateAndCancel()
            completion(result)
        }
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
            finish(.failure(.unavailable))
        }
        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let response = response as? HTTPURLResponse, response.url == request.url else {
                completionHandler(.cancel); finish(.failure(.unavailable)); return
            }
            do {
                try ScriptWidgetServiceResponseDecoder.validateHTTP(status: response.statusCode,
                    contentType: response.value(forHTTPHeaderField: "Content-Type"), expectedBytes: response.expectedContentLength,
                    rateLimited: response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0" || response.value(forHTTPHeaderField: "Retry-After") != nil)
                status = response.statusCode
                completionHandler(.allow)
            } catch {
                completionHandler(.cancel); finish(.failure(error as? ScriptWidgetServiceError ?? .unavailable))
            }
        }
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard !completed else { return }
            guard data.count <= ScriptWidgetServiceURLTransport.maximumResponseBytes - body.count else {
                finish(.failure(.unavailable)); return
            }
            body.append(data)
        }
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard !completed else { return }
            if let error { finish(.failure((error as NSError).code == NSURLErrorCancelled ? .cancelled : .unavailable)) }
            else if let status { finish(.success(.init(status: status, body: body))) }
            else { finish(.failure(.unavailable)) }
        }
    }
}

enum ScriptWidgetServiceResponseDecoder {
    static func validateHTTP(status: Int, contentType: String?, expectedBytes: Int64, rateLimited: Bool = false) throws {
        guard expectedBytes <= ScriptWidgetServiceURLTransport.maximumResponseBytes else { throw ScriptWidgetServiceError.unavailable }
        if status == 401 { throw ScriptWidgetServiceError.expiredAuthorization }
        if status == 429 || (status == 403 && rateLimited) { throw ScriptWidgetServiceError.rateLimited }
        if status == 403 { throw ScriptWidgetServiceError.permissionDenied }
        guard status == 200 || status == 204 else { throw ScriptWidgetServiceError.unavailable }
        if status == 200 {
            let mime = contentType?.split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces).lowercased()
            guard mime == "application/json" else { throw ScriptWidgetServiceError.unavailable }
        }
    }

    private struct Fields {
        let object: [String: Any]
        let secrets: [String]
        init(_ object: [String: Any], secrets: [String]) { self.object = object; self.secrets = secrets }
        func text(_ key: String, required: Bool = false, maximum: Int = 256) throws -> String? {
            guard let raw = object[key], !(raw is NSNull) else {
                if required { throw ScriptWidgetServiceError.unavailable }; return nil
            }
            guard let value = raw as? String, value.utf8.count <= maximum,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !secrets.contains(where: { !($0.isEmpty) && value.contains($0) }) else { throw ScriptWidgetServiceError.unavailable }
            if required && value.isEmpty { throw ScriptWidgetServiceError.unavailable }
            return value
        }
        func integer(_ key: String, required: Bool = false, maximum: Int = 9_007_199_254_740_991) throws -> Int? {
            guard let raw = object[key], !(raw is NSNull) else {
                if required { throw ScriptWidgetServiceError.unavailable }; return nil
            }
            guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite,
                  value.doubleValue >= 0, value.doubleValue <= Double(maximum), value.doubleValue.rounded() == value.doubleValue else { throw ScriptWidgetServiceError.unavailable }
            return value.intValue
        }
        func boolean(_ key: String, fallback: Bool? = nil) throws -> Bool {
            guard let raw = object[key] else {
                if let fallback { return fallback }; throw ScriptWidgetServiceError.unavailable
            }
            guard let value = raw as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { throw ScriptWidgetServiceError.unavailable }
            return value.boolValue
        }
        func fields(_ key: String) throws -> Fields? {
            guard let raw = object[key], !(raw is NSNull) else { return nil }
            guard let value = raw as? [String: Any] else { throw ScriptWidgetServiceError.unavailable }
            return .init(value, secrets: secrets)
        }
    }

    static func decode(_ response: ScriptWidgetServiceHTTPResponse, operation: ScriptWidgetServiceOperation, credential: ScriptWidgetServiceCredential) throws -> ScriptWidgetServiceResponse {
        guard !operation.isWrite, operation.service == credential.service else { throw ScriptWidgetServiceError.unsupportedOperation }
        try credential.validate()
        let data = response.body
        guard data.count <= ScriptWidgetServiceURLTransport.maximumResponseBytes else { throw ScriptWidgetServiceError.unavailable }
        if response.status == 204 && data.isEmpty && operation == .spotifyPlayback { return .playback(nil) }
        guard response.status == 200 else { throw ScriptWidgetServiceError.unavailable }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ScriptWidgetServiceError.unavailable }
        let fields = Fields(object, secrets: [credential.accessToken, credential.refreshToken].compactMap { $0 })
        switch operation {
        case .githubProfile:
            guard let id = try fields.integer("id", required: true), id > 0,
                  let username = try fields.text("login", required: true, maximum: 39),
                  username.range(of: #"^[A-Za-z0-9][A-Za-z0-9_-]{0,38}$"#, options: .regularExpression) != nil else { throw ScriptWidgetServiceError.unavailable }
            return .profile(.init(service: .github, subject: String(id), username: username, displayName: try fields.text("name"),
                publicRepositories: try fields.integer("public_repos", required: true), privateRepositories: try fields.integer("total_private_repos"),
                followers: try fields.integer("followers"), following: try fields.integer("following")))
        case .spotifyProfile:
            guard let id = try fields.text("id", required: true, maximum: 128) else { throw ScriptWidgetServiceError.unavailable }
            return .profile(.init(service: .spotify, subject: id, username: nil, displayName: try fields.text("display_name"),
                publicRepositories: nil, privateRepositories: nil, followers: nil, following: nil))
        case .spotifyPlayback:
            let type = try fields.text("currently_playing_type", required: true, maximum: 32)!
            let playing = try fields.boolean("is_playing"), progress = try fields.integer("progress_ms", maximum: 7 * 86_400_000)
            let device = try fields.fields("device")
            let active = try device?.boolean("is_active", fallback: false) ?? false
            let restricted = try device?.boolean("is_restricted", fallback: true) ?? true
            guard ["track", "episode"].contains(type), let item = try fields.fields("item") else {
                return .playback(.init(itemType: "unsupported", itemID: nil, title: nil, artists: [], album: nil, isPlaying: playing,
                    progressMilliseconds: progress, durationMilliseconds: nil, hasActiveDevice: active, isRestricted: restricted))
            }
            let id = try item.text("id", maximum: 128), duration = try item.integer("duration_ms", required: true, maximum: 7 * 86_400_000)
            var artists: [String] = []
            if type == "track", let raw = item.object["artists"] {
                guard let values = raw as? [[String: Any]], values.count <= 32 else { throw ScriptWidgetServiceError.unavailable }
                artists = try values.prefix(8).map { try Fields($0, secrets: fields.secrets).text("name", required: true)! }
            }
            let album = try type == "track" ? item.fields("album")?.text("name") : item.fields("show")?.text("name")
            return .playback(.init(itemType: type, itemID: id, title: try item.text("name", required: true), artists: artists, album: album,
                isPlaying: playing, progressMilliseconds: progress, durationMilliseconds: duration, hasActiveDevice: active, isRestricted: restricted))
        default: throw ScriptWidgetServiceError.unsupportedOperation
        }
    }
}

/// Read-only broker. Writes stay disabled until durable action receipts exist.
/// Revalidation runs before dispatch AND before delivery, even after a failure.
final class ScriptWidgetServiceReader {
    private let transport: any ScriptWidgetServiceHTTPTransport
    init(transport: any ScriptWidgetServiceHTTPTransport = ScriptWidgetServiceURLTransport()) { self.transport = transport }

    @discardableResult func read(_ plan: ScriptWidgetServiceRequestPlan, credential: ScriptWidgetServiceCredential,
        revalidate: @escaping () throws -> Void, completion: @escaping (Result<ScriptWidgetServiceResponse, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        guard !plan.operation.isWrite, plan.accountID == credential.accountID, plan.operation.service == credential.service,
              plan.request.value(forHTTPHeaderField: "Authorization") == "Bearer " + credential.accessToken else {
            completion(.failure(.unsupportedOperation)); return .init({})
        }
        do { try revalidate() } catch { completion(.failure(error as? ScriptWidgetServiceError ?? .unavailable)); return .init({}) }
        return transport.send(plan.request) { result in
            let decoded = result.flatMap { response in
                do { return .success(try ScriptWidgetServiceResponseDecoder.decode(response, operation: plan.operation, credential: credential)) }
                catch { return .failure(error as? ScriptWidgetServiceError ?? .unavailable) }
            }
            do { try revalidate(); completion(decoded) }
            catch { completion(.failure(error as? ScriptWidgetServiceError ?? .unavailable)) }
        }
    }

    /// Native account settings may verify a credential before granting widgets
    /// anything. This entry point is never exposed as a JavaScript global.
    @discardableResult func verifyConnection(_ credential: ScriptWidgetServiceCredential,
        completion: @escaping (Result<ScriptWidgetServiceProfile, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        do {
            let operation: ScriptWidgetServiceOperation = credential.service == .github ? .githubProfile : .spotifyProfile
            let owner = UUID(), empty = ScriptWidgetServiceAccessPolicy.connected(accountID: credential.accountID, service: credential.service)
            let policy = try empty.updatingGrant(ownerID: owner, operations: [operation], expectedRevision: empty.revision)
            let plan = try ScriptWidgetServiceRequestPlan(operation: operation, credential: credential, policy: policy, ownerID: owner,
                expectedConnectionID: policy.connectionID, isUserInitiatedAction: false, hasNetworkPermission: true, allowsHost: { _ in true })
            return read(plan, credential: credential, revalidate: {}) { result in
                completion(result.flatMap { value in
                    guard case let .profile(profile) = value else { return .failure(.unavailable) }
                    return .success(profile)
                })
            }
        } catch { completion(.failure(error as? ScriptWidgetServiceError ?? .unavailable)); return .init({}) }
    }
}
