import SwiftUI
import AuthenticationServices
import WidgetKit

/// Only the signed app bundle can configure this integration. Widgets and
/// imported packages cannot supply a client, endpoint or callback registration.
enum ScriptWidgetSpotifyConfiguration {
    static func clientID(info: [String: Any]) -> String? {
        guard let client = ScriptWidgetServiceProviderConfiguration.spotifyClientID(info: info),
              let types = info["CFBundleURLTypes"] as? [[String: Any]],
              types.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(ScriptWidgetSpotifyAuthorization.callbackScheme) == true }) else { return nil }
        return client
    }
    static var clientID: String? { clientID(info: Bundle.main.infoDictionary ?? [:]) }
}

@MainActor
protocol ScriptWidgetSpotifyWebAuthorizing: AnyObject {
    func start(_ authorization: ScriptWidgetSpotifyAuthorization,
               completion: @escaping @MainActor (Result<URL, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle
}

/// The system owns the browser and callback delivery; PKCE still verifies the
/// complete callback's host, path, state and one-time code in TokenClient.
@MainActor
final class ScriptWidgetSpotifyWebAuthorization: NSObject, ScriptWidgetSpotifyWebAuthorizing, ASWebAuthenticationPresentationContextProviding {
    private weak var anchor: ASPresentationAnchor?
    private var started = false
    private var session: ASWebAuthenticationSession?
    private var completion: (@MainActor (Result<URL, ScriptWidgetServiceError>) -> Void)?
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    // A closed window must fail presentation rather than select another scene.
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor ?? ASPresentationAnchor() }
    func start(_ authorization: ScriptWidgetSpotifyAuthorization,
               completion: @escaping @MainActor (Result<URL, ScriptWidgetServiceError>) -> Void) -> ScriptWidgetServiceRequestHandle {
        guard !started else { completion(.failure(.conflict)); return .init({}) }
        guard anchor != nil else { completion(.failure(.authorizationFailed)); return .init({}) }
        started = true
        self.completion = completion
        let callback: ASWebAuthenticationSession.CompletionHandler = { [weak self] url, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    let value = error as NSError
                    self.finish(.failure(value.domain == ASWebAuthenticationSessionErrorDomain && value.code == ASWebAuthenticationSessionError.canceledLogin.rawValue ? .cancelled : .authorizationFailed))
                } else if let url { self.finish(.success(url)) }
                else { self.finish(.failure(.authorizationFailed)) }
            }
        }
        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, macOS 14.4, *) {
            session = .init(url: authorization.authorizationURL, callback: .customScheme(ScriptWidgetSpotifyAuthorization.callbackScheme), completionHandler: callback)
        } else {
            session = .init(url: authorization.authorizationURL, callbackURLScheme: ScriptWidgetSpotifyAuthorization.callbackScheme, completionHandler: callback)
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = true
        self.session = session
        if !session.canStart || !session.start() { finish(.failure(.authorizationFailed)) }
        return .init { [self] in Task { @MainActor in self.cancel() } }
    }
    private func finish(_ result: Result<URL, ScriptWidgetServiceError>) {
        let callback = completion; completion = nil; session = nil; callback?(result)
    }
    private func cancel() {
        let saved = session
        finish(.failure(.cancelled)); saved?.cancel()
    }
}

/// A foreground app lease spans browser/HTTP work without holding a storage
/// lock. Extensions do not prompt or refresh; background refresh is separate.
@MainActor
private enum ScriptWidgetSpotifyInteractiveLease {
    static var active: UUID?
    static func acquire() throws -> UUID {
        guard active == nil else { throw ScriptWidgetServiceError.conflict }
        let id = UUID(); active = id; return id
    }
    static func release(_ id: UUID?) { if let id, active == id { active = nil } }
}

@MainActor
final class ScriptWidgetSpotifyAccountsModel: ObservableObject {
    enum Phase { case idle, authorizing, exchanging, verifying, refreshing, verifyingRefresh }
    struct Summary: Equatable {
        let label: String
        let revision: UUID
        let expiresAt: Date?
        let grantedOwners: Set<UUID>
        let playbackOwners: Set<UUID>
        init(_ connection: ScriptWidgetServiceConnection) {
            label = connection.label; revision = connection.revision; expiresAt = connection.credential.expiresAt
            grantedOwners = Set(connection.policy.grants.filter { $0.operations.contains(.spotifyProfile) }.map(\.ownerID))
            playbackOwners = Set(connection.policy.grants.filter { $0.operations.contains(.spotifyPlayback) }.map(\.ownerID))
        }
    }
    @Published private(set) var connection: Summary?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var ready = false
    @Published private(set) var message: String?
    @Published private(set) var owners: [ScriptWidgetServiceAccountsModel.Owner] = []
    @Published private(set) var ownerMessage: String?
    let clientID: String?
    var busy: Bool { phase != .idle }
    private var store: ScriptWidgetServiceConnections?
    private let tokens: ScriptWidgetSpotifyTokenClient
    private let reader: ScriptWidgetServiceReader
    private var authorizer: (any ScriptWidgetSpotifyWebAuthorizing)?
    private var request: ScriptWidgetServiceRequestHandle?
    private var attempt = UUID()
    private var lease: UUID?
    private let loadOwners: @MainActor () throws -> [ScriptWidgetServiceAccountsModel.Owner]

    init(clientID: String? = ScriptWidgetSpotifyConfiguration.clientID, store: ScriptWidgetServiceConnections? = nil,
         tokens: ScriptWidgetSpotifyTokenClient = .init(), reader: ScriptWidgetServiceReader = .init(),
         loadOwners: (@MainActor () throws -> [ScriptWidgetServiceAccountsModel.Owner])? = nil) {
        self.clientID = clientID.flatMap { ScriptWidgetSpotifyAuthorization.validClientID($0) ? $0 : nil }
        self.store = store; self.tokens = tokens; self.reader = reader
        self.loadOwners = loadOwners ?? ScriptWidgetServiceAccountsModel.nativeOwners
    }
    deinit {
        let id = lease, pending = request
        Task { @MainActor in ScriptWidgetSpotifyInteractiveLease.release(id); pending?.cancel() }
    }
    private func resolvedStore() throws -> ScriptWidgetServiceConnections {
        if let store { return store }; let value = try ScriptWidgetServiceConnections.live(); store = value; return value
    }
    func reload() {
        guard !busy else { return }
        do { connection = try resolvedStore().connection(.spotify).map(Summary.init); ready = true; message = nil }
        catch { ready = false; connection = nil; message = (error as? ScriptWidgetServiceError ?? .storageUnavailable).localizedDescription }
        do { owners = try loadOwners(); ownerMessage = nil }
        catch { owners = []; ownerMessage = "Open an available widget library to choose which widgets can read this account." }
    }
    private func validate(_ expected: ScriptWidgetServiceConnection?) throws {
        if let expected { try resolvedStore().revalidate(expected) }
        else if try resolvedStore().connection(.spotify) != nil { throw ScriptWidgetServiceError.conflict }
    }
    private func start(_ phase: Phase) throws -> UUID {
        guard ready, !busy, clientID != nil else { throw ScriptWidgetServiceError.invalidConfiguration }
        lease = try ScriptWidgetSpotifyInteractiveLease.acquire()
        attempt = UUID(); self.phase = phase; message = nil; return attempt
    }
    private func finish(_ error: Error? = nil) {
        request = nil; authorizer = nil; phase = .idle
        ScriptWidgetSpotifyInteractiveLease.release(lease); lease = nil
        message = error.map { ($0 as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
    func cancel() {
        attempt = UUID(); let pending = request; finish(); pending?.cancel()
    }
    func connect(using authorizer: any ScriptWidgetSpotifyWebAuthorizing) {
        guard !busy else { return }
        do {
            let expected = try resolvedStore().connection(.spotify)
            guard expected?.revision == connection?.revision else { throw ScriptWidgetServiceError.conflict }
            guard let clientID else { throw ScriptWidgetServiceError.invalidConfiguration }
            let authorization = try ScriptWidgetSpotifyAuthorization(clientID: clientID, playbackControl: false)
            let id = try start(.authorizing), account = UUID()
            self.authorizer = authorizer
            request = authorizer.start(authorization) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.attempt == id, self.phase == .authorizing else { return }
                    do {
                        let callback = try result.get(); try self.validate(expected)
                        self.phase = .exchanging
                        self.request = self.tokens.exchange(authorization, callback: callback, accountID: account) { [weak self] result in
                            Task { @MainActor in self?.received(result, id: id, expected: expected, refreshing: false) }
                        }
                    } catch { self.finish(error) }
                }
            }
        } catch { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
    func refresh() {
        guard !busy else { return }
        do {
            guard let expected = try resolvedStore().connection(.spotify), expected.revision == connection?.revision else { throw ScriptWidgetServiceError.conflict }
            guard expected.credential.oauthClientID == clientID else { throw ScriptWidgetServiceError.invalidConfiguration }
            let id = try start(.refreshing)
            try validate(expected)
            request = tokens.refresh(expected.credential) { [weak self] result in
                Task { @MainActor in self?.received(result, id: id, expected: expected, refreshing: true) }
            }
        } catch { if busy { finish(error) } else { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription } }
    }
    private func received(_ result: Result<ScriptWidgetServiceCredential, ScriptWidgetServiceError>, id: UUID,
                          expected: ScriptWidgetServiceConnection?, refreshing: Bool) {
        guard attempt == id, phase == (refreshing ? .refreshing : .exchanging) else { return }
        do {
            let credential = try result.get(); try validate(expected)
            phase = refreshing ? .verifyingRefresh : .verifying
            request = reader.verifyConnection(credential) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.attempt == id, self.phase == (refreshing ? .verifyingRefresh : .verifying) else { return }
                    do {
                        let profile = try result.get(); try self.validate(expected)
                        guard profile.service == .spotify else { throw ScriptWidgetServiceError.invalidCredential }
                        let saved: ScriptWidgetServiceConnection
                        if refreshing {
                            guard let expected, profile.subject == expected.subject else { throw ScriptWidgetServiceError.invalidCredential }
                            saved = try self.resolvedStore().refreshCredential(credential, expected: expected)
                        } else { saved = try self.resolvedStore().connect(credential, verifiedProfile: profile, expectedRevision: expected?.revision) }
                        self.connection = .init(saved); self.finish(); WidgetCenter.shared.reloadAllTimelines()
                    } catch { self.finish(error) }
                }
            }
        } catch { finish(error) }
    }
    func disconnect() {
        guard ready, !busy, let connection else { return }
        do { try resolvedStore().disconnect(.spotify, expectedRevision: connection.revision); self.connection = nil; message = nil; WidgetCenter.shared.reloadAllTimelines() }
        catch { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
    func setGranted(_ granted: Bool, owner: ScriptWidgetServiceAccountsModel.Owner, operation: ScriptWidgetServiceOperation = .spotifyProfile) {
        guard operation == .spotifyProfile || operation == .spotifyPlayback else { return }
        guard ready, !busy, let connection else { return }
        do {
            try owner.validate()
            guard let current = try resolvedStore().connection(.spotify), current.credential.oauthClientID == clientID else {
                throw ScriptWidgetServiceError.invalidConfiguration
            }
            var operations = current.policy.grants.first(where: { $0.ownerID == owner.id })?.operations ?? []
            if granted { operations.insert(operation) } else { operations.remove(operation) }
            let saved = try resolvedStore().setGrant(service: .spotify, ownerID: owner.id, operations: operations, expectedRevision: connection.revision)
            self.connection = .init(saved); message = nil; WidgetCenter.shared.reloadAllTimelines()
        } catch { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
}

struct ScriptWidgetSpotifyAccountSection: View {
    @ObservedObject var model: ScriptWidgetSpotifyAccountsModel
    @ObservedObject var window: ScriptWidgetServiceWindowReference
    var body: some View {
        Section {
            if let connection = model.connection {
                Label("Connected as \(connection.label)", systemImage: "checkmark.shield")
                if let date = connection.expiresAt { Text("Connection expires \(date.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(.secondary) }
                Button("Refresh Spotify Connection") { model.refresh() }.disabled(model.busy || !model.ready || model.clientID == nil)
                Button("Disconnect Spotify from This Device", role: .destructive) { model.disconnect() }.disabled(model.busy || !model.ready)
                ForEach(model.owners) { owner in
                    Toggle("Profile access: \(owner.name)", isOn: Binding(get: { connection.grantedOwners.contains(owner.id) }, set: { model.setGranted($0, owner: owner) }))
                        .disabled(model.busy || !model.ready || model.clientID == nil)
                    Toggle("Playback access: \(owner.name)", isOn: Binding(get: { connection.playbackOwners.contains(owner.id) }, set: { model.setGranted($0, owner: owner, operation: .spotifyPlayback) }))
                        .disabled(model.busy || !model.ready || model.clientID == nil)
                }
                if let message = model.ownerMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
            } else if model.clientID == nil {
                Text("Spotify connection is not available in this build.").foregroundStyle(.secondary)
            } else {
                Text("Sign in with Spotify to connect your profile and playback account. This does not grant widgets access automatically.").font(.footnote).foregroundStyle(.secondary)
                Button(model.busy ? "Connecting…" : "Connect Spotify") {
                    if let anchor = window.window { model.connect(using: ScriptWidgetSpotifyWebAuthorization(anchor: anchor)) }
                }.disabled(model.busy || !model.ready || window.window == nil)
            }
            if model.busy { Button("Cancel Spotify Connection") { model.cancel() } }
            if model.connection != nil || model.clientID != nil { Link("Manage Spotify App Access", destination: URL(string: "https://www.spotify.com/account/apps/")!) }
            if let message = model.message, model.clientID != nil || model.connection != nil {
                Text(message.replacingOccurrences(of: #"^\[service_[a-z_]+\] "#, with: "", options: .regularExpression)).foregroundStyle(.red)
                Button("Reload Spotify Settings") { model.reload() }.disabled(model.busy)
            }
        } header: { Text("Spotify") }
    }
}

/// Resolve the actual presenting window without UIApplication/NSApplication
/// singletons, so the shared source remains valid in extension targets.
@MainActor
final class ScriptWidgetServiceWindowReference: ObservableObject {
    private(set) weak var window: ASPresentationAnchor?
    func update(_ value: ASPresentationAnchor?) {
        guard window !== value else { return }
        objectWillChange.send(); window = value
    }
}

struct ScriptWidgetServicePresentationWindow: View {
    @ObservedObject var reference: ScriptWidgetServiceWindowReference
    var body: some View { Reader(changed: reference.update).frame(width: 0, height: 0).accessibilityHidden(true) }
    #if os(macOS)
    private struct Reader: NSViewRepresentable {
        let changed: (ASPresentationAnchor?) -> Void
        final class Surface: NSView {
            var changed: ((NSWindow?) -> Void)?
            override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); changed?(window) }
        }
        func makeNSView(context: Context) -> Surface { let view = Surface(); updateNSView(view, context: context); return view }
        func updateNSView(_ view: Surface, context: Context) { view.changed = { value in DispatchQueue.main.async { changed(value) } } }
    }
    #else
    private struct Reader: UIViewRepresentable {
        let changed: (ASPresentationAnchor?) -> Void
        final class Surface: UIView {
            var changed: ((UIWindow?) -> Void)?
            override func didMoveToWindow() { super.didMoveToWindow(); changed?(window) }
        }
        func makeUIView(context: Context) -> Surface { let view = Surface(); updateUIView(view, context: context); return view }
        func updateUIView(_ view: Surface, context: Context) { view.changed = { value in DispatchQueue.main.async { changed(value) } } }
    }
    #endif
}
