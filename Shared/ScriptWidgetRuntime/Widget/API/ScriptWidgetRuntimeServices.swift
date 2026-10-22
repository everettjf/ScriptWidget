import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeServicesExports: JSExport {
    static func status(_ service: String) -> ScriptWidgetRuntimePromise
    static func profile(_ service: String) -> ScriptWidgetRuntimePromise
    static func playback(_ service: String) -> ScriptWidgetRuntimePromise
}

/// No auth prompts, token access, arbitrary URL/header arguments or writes.
/// Spotify requires matching signed app/widget client configuration and an
/// explicitly granted native account. No scripts can start login or refresh.
@objc final class ScriptWidgetRuntimeServices: NSObject, ScriptWidgetRuntimeServicesExports {
    private static let queue = DispatchQueue(label: "ScriptWidget.Services", qos: .userInitiated)
    private enum Query { case status, profile, playback }
    static func status(_ service: String) -> ScriptWidgetRuntimePromise { query(service, kind: .status) }
    static func profile(_ service: String) -> ScriptWidgetRuntimePromise { query(service, kind: .profile) }
    static func playback(_ service: String) -> ScriptWidgetRuntimePromise { query(service, kind: .playback) }

    static func validate(_ state: ScriptWidgetRunningState) throws -> UUID {
        guard state.isCurrentExecution, state.previewStorage == nil, let snapshot = state.executionSnapshot,
              let owner = UUID(uuidString: snapshot.binding.ownerID), let manifest = state.package.readManifest(),
              manifest.permissions.contains(.services),
              WidgetPackageManifestValidator.validate(manifest, package: state.package, checkEntryExists: false).isValid else {
            throw ScriptWidgetServiceError.permissionDenied
        }
        return owner
    }

    private static func connections(_ state: ScriptWidgetRunningState) throws -> ScriptWidgetServiceConnections {
        #if DEBUG
        if let value = state.serviceConnectionsForTesting { return value }
        #endif
        return try .live()
    }
    private static func reader(_ state: ScriptWidgetRunningState) -> ScriptWidgetServiceReader {
        #if DEBUG
        if let value = state.serviceReaderForTesting { return value }
        #endif
        return .init()
    }
    private static func spotifyClientID(_ state: ScriptWidgetRunningState) -> String? {
        #if DEBUG
        if let info = state.serviceProviderInfoForTesting { return ScriptWidgetServiceProviderConfiguration.spotifyClientID(info: info) }
        #endif
        return ScriptWidgetServiceProviderConfiguration.spotifyClientID
    }
    private static func query(_ name: String, kind: Query) -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state else { reject.call(withArguments: [ScriptWidgetServiceError.permissionDenied.localizedDescription]); return }
            let owner: UUID
            do { owner = try validate(state) }
            catch { reject.call(withArguments: [ScriptWidgetServiceError.permissionDenied.localizedDescription]); return }
            guard let service = ScriptWidgetService(rawValue: name), kind != .playback || service == .spotify else {
                reject.call(withArguments: [ScriptWidgetServiceError.unsupportedOperation.localizedDescription]); return
            }
            guard !state.isTimelineProjection && !state.isLiveActivityPresentation else {
                reject.call(withArguments: ["[timeline_read_only] Read services in the current entry, then reuse a display snapshot"]); return
            }
            guard state.executionSession.registerDataQuery() else { reject.call(withArguments: ["[query_limit] Too many system data queries"]); return }
            let spotifyClient = service == .spotify ? spotifyClientID(state) : nil
            if service == .spotify && spotifyClient == nil {
                if kind != .status { reject.call(withArguments: [ScriptWidgetServiceError.unsupportedOperation.localizedDescription]) }
                else { resolve.call(withArguments: ["unavailable"]) }
                return
            }
            let pending = ScriptWidgetServiceExecutionQuery(session: state.executionSession)
            guard pending.register() else { reject.call(withArguments: ["[execution_inactive] Service query was cancelled"]); return }
            queue.async {
                do {
                    guard try validate(state) == owner else { throw ScriptWidgetServiceError.permissionDenied }
                    let store = try connections(state), connection = try store.connection(service)
                    let operation: ScriptWidgetServiceOperation = kind == .playback ? .spotifyPlayback : service == .github ? .githubProfile : .spotifyProfile
                    if let connection, service == .spotify, connection.credential.oauthClientID != spotifyClient {
                        throw ScriptWidgetServiceError.invalidCredential
                    }
                    func validateCurrent() throws {
                        guard try validate(state) == owner else { throw ScriptWidgetServiceError.permissionDenied }
                        if let connection { try store.revalidate(connection) }
                        else if try store.connection(service) != nil { throw ScriptWidgetServiceError.conflict }
                    }
                    if kind == .status {
                        let status = connection == nil ? "notConnected" : connection!.policy.grants.contains(where: { $0.ownerID == owner && $0.operations.contains(operation) }) ? "connected" : "notGranted"
                        state.executionSession.callbackQueue.async {
                            pending.complete()
                            guard state.isCurrentExecution else { return }
                            do { try validateCurrent(); resolve.call(withArguments: [status]) }
                            catch { reject.call(withArguments: [(error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription]) }
                        }
                        return
                    }
                    guard let connection else { throw ScriptWidgetServiceError.notConnected }
                    guard let manifest = state.package.readManifest() else { throw ScriptWidgetServiceError.permissionDenied }
                    let plan = try ScriptWidgetServiceRequestPlan(operation: operation, credential: connection.credential, policy: connection.policy,
                        ownerID: owner, expectedConnectionID: connection.policy.connectionID, isUserInitiatedAction: false,
                        hasNetworkPermission: manifest.permissions.contains(.network),
                        allowsHost: { ScriptWidgetNetworkPolicy.host($0, matchesAny: manifest.networkDomains) })
                    guard pending.reserveNetwork() else { throw ScriptWidgetServiceError.networkLimit }
                    let task = reader(state).read(plan, credential: connection.credential, revalidate: validateCurrent) { result in
                        state.executionSession.callbackQueue.async {
                            pending.complete()
                            guard state.isCurrentExecution else { return }
                            do {
                                try validateCurrent()
                                let response = try result.get()
                                if kind == .playback {
                                    guard case let .playback(value) = response else { throw ScriptWidgetServiceError.unavailable }
                                    guard let value else { resolve.call(withArguments: [NSNull()]); return }
                                    resolve.call(withArguments: [["itemType": value.itemType, "itemID": value.itemID as Any? ?? NSNull(),
                                        "title": value.title as Any? ?? NSNull(), "artists": value.artists, "album": value.album as Any? ?? NSNull(),
                                        "isPlaying": value.isPlaying, "progressMilliseconds": value.progressMilliseconds as Any? ?? NSNull(),
                                        "durationMilliseconds": value.durationMilliseconds as Any? ?? NSNull(), "hasActiveDevice": value.hasActiveDevice,
                                        "isRestricted": value.isRestricted]])
                                } else {
                                    guard case let .profile(value) = response, value.service == service, value.subject == connection.subject else { throw ScriptWidgetServiceError.invalidCredential }
                                    resolve.call(withArguments: [["service": value.service.rawValue, "subject": value.subject,
                                        "username": value.username as Any? ?? NSNull(), "displayName": value.displayName as Any? ?? NSNull(),
                                        "publicRepositories": value.publicRepositories as Any? ?? NSNull(), "privateRepositories": value.privateRepositories as Any? ?? NSNull(),
                                        "followers": value.followers as Any? ?? NSNull(), "following": value.following as Any? ?? NSNull()]])
                                }
                            } catch { reject.call(withArguments: [(error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription]) }
                        }
                    }
                    pending.install(task)
                } catch {
                    pending.complete()
                    guard state.isCurrentExecution else { return }
                    let failure = error as? ScriptWidgetServiceError ?? .unavailable
                    if failure == .invalidConfiguration && kind == .status { resolve.call(withArguments: ["unavailable"]) }
                    else { reject.call(withArguments: [(failure == .invalidConfiguration ? ScriptWidgetServiceError.unavailable : failure).localizedDescription]) }
                }
            }
        }
    }
}

/// Covers cancellation before a transport returns its handle and synchronous
/// fixture completion. Network reservations share the ordinary fetch budget.
private final class ScriptWidgetServiceExecutionQuery {
    private let session: ScriptWidgetExecutionSession
    private let cancellation: ScriptWidgetQueryCancellation
    private let lock = NSLock()
    private var task: ScriptWidgetServiceRequestHandle?
    private var reservation: UUID?
    private var finished = false
    init(session: ScriptWidgetExecutionSession) { self.session = session; cancellation = .init(session: session) }
    func register() -> Bool { cancellation.install { self.cancel() } }
    func reserveNetwork() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !finished, let id = session.registerServiceNetworkRequest() else { return false }
        reservation = id; return true
    }
    func install(_ task: ScriptWidgetServiceRequestHandle) {
        lock.lock(); if finished { lock.unlock(); task.cancel(); return }; self.task = task; lock.unlock()
    }
    func complete() {
        lock.lock(); finished = true; task = nil; let id = reservation; reservation = nil; lock.unlock()
        if let id { session.completeServiceNetworkRequest(id) }; cancellation.complete()
    }
    private func cancel() {
        lock.lock(); finished = true; let saved = task; task = nil; let id = reservation; reservation = nil; lock.unlock()
        saved?.cancel(); if let id { session.completeServiceNetworkRequest(id) }; cancellation.complete()
    }
}
