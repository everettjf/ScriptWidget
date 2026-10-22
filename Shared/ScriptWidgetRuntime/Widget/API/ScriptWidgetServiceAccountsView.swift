import SwiftUI
import WidgetKit
import AuthenticationServices

struct ScriptWidgetServiceConnectionSummary: Equatable {
    let label: String
    let revision: UUID
    let grantedOwners: Set<UUID>
    init(_ connection: ScriptWidgetServiceConnection) {
        label = connection.label; revision = connection.revision
        grantedOwners = Set(connection.policy.grants.filter { $0.operations.contains(.githubProfile) }.map(\.ownerID))
    }
}

@MainActor
final class ScriptWidgetServiceAccountsModel: ObservableObject {
    struct Owner: Identifiable {
        let id: UUID
        let name: String
        let validate: () throws -> Void
    }
    @Published private(set) var connection: ScriptWidgetServiceConnectionSummary?
    @Published private(set) var owners: [Owner] = []
    @Published private(set) var ready = false
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var ownerMessage: String?
    private var store: ScriptWidgetServiceConnections?
    private let reader: ScriptWidgetServiceReader
    private var request: ScriptWidgetServiceRequestHandle?
    private var generation = UUID()
    private let loadOwners: @MainActor () throws -> [Owner]

    init(store: ScriptWidgetServiceConnections? = nil, reader: ScriptWidgetServiceReader = .init(), loadOwners: (@MainActor () throws -> [Owner])? = nil) {
        self.store = store; self.reader = reader; self.loadOwners = loadOwners ?? Self.nativeOwners
    }

    private static func nativeOwners() throws -> [Owner] {
        let manager = sharedScriptManager
        guard let context = manager.storageContext else { throw ScriptWidgetServiceError.unavailable }
        return manager.listScripts().prefix(256).compactMap { item -> Owner? in
            guard let binding = try? context.boundDirectory(name: item.name, role: .source),
                  let id = UUID(uuidString: binding.ownerID) else { return nil }
            return Owner(id: id, name: item.name, validate: {
                let current = try context.boundDirectory(name: item.name, role: .source)
                guard current.ownerID == binding.ownerID else { throw ScriptWidgetServiceError.conflict }
            })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func resolvedStore() throws -> ScriptWidgetServiceConnections {
        if let store { return store }
        let value = try ScriptWidgetServiceConnections.live(); store = value; return value
    }
    func reload() {
        guard !busy else { return }
        do {
            connection = try resolvedStore().connection(.github).map(ScriptWidgetServiceConnectionSummary.init)
            ready = true; message = nil
        } catch { ready = false; connection = nil; message = (error as? ScriptWidgetServiceError ?? .storageUnavailable).localizedDescription }
        do { owners = try loadOwners(); ownerMessage = nil }
        catch { owners = []; ownerMessage = "Open an available widget library to choose which widgets can read this account." }
    }
    func cancel() {
        generation = UUID(); request?.cancel(); request = nil; busy = false
    }
    func connectGitHub(token: String) {
        guard ready, !busy else { return }
        let expected = connection?.revision, attempt = UUID()
        generation = attempt; busy = true; message = nil
        let credential = ScriptWidgetServiceCredential(formatVersion: 1, accountID: UUID(), service: .github, revision: UUID(),
            accessToken: token, refreshToken: nil, oauthClientID: nil, issuedAt: Date(), expiresAt: nil, scopes: [])
        do { try credential.validate() }
        catch { busy = false; message = ScriptWidgetServiceError.invalidCredential.localizedDescription; return }
        request = reader.verifyConnection(credential) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation == attempt else { return }
                self.request = nil; self.busy = false
                do {
                    let profile = try result.get()
                    let saved = try self.resolvedStore().connect(credential, verifiedProfile: profile, expectedRevision: expected)
                    self.connection = .init(saved); self.message = nil
                    WidgetCenter.shared.reloadAllTimelines()
                } catch { self.message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
            }
        }
    }
    func setGranted(_ granted: Bool, owner: Owner) {
        guard ready, !busy, let connection else { return }
        do {
            try owner.validate()
            let changed = try resolvedStore().setGrant(service: .github, ownerID: owner.id, operations: granted ? [.githubProfile] : [], expectedRevision: connection.revision)
            self.connection = .init(changed); message = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
    func disconnect() {
        guard ready, !busy, let connection else { return }
        do {
            try resolvedStore().disconnect(.github, expectedRevision: connection.revision)
            self.connection = nil; message = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch { message = (error as? ScriptWidgetServiceError ?? .unavailable).localizedDescription }
    }
}

struct ScriptWidgetServiceAccountsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: ScriptWidgetServiceAccountsModel
    @StateObject private var spotify: ScriptWidgetSpotifyAccountsModel
    @StateObject private var presentationWindow = ScriptWidgetServiceWindowReference()
    @State private var token = ""
    @State private var reconnecting = false
    init(model: ScriptWidgetServiceAccountsModel? = nil, spotifyModel: ScriptWidgetSpotifyAccountsModel? = nil) {
        _model = StateObject(wrappedValue: model ?? ScriptWidgetServiceAccountsModel())
        _spotify = StateObject(wrappedValue: spotifyModel ?? ScriptWidgetSpotifyAccountsModel())
    }
    var body: some View {
        Form {
            Section {
                Label(model.connection.map { "Connected as \($0.label)" } ?? "Connect GitHub", systemImage: model.connection == nil ? "person.crop.circle.badge.plus" : "checkmark.shield")
                    .font(.headline)
                if model.connection == nil {
                    Text("Connect with a GitHub personal access token. A fine-grained token needs no additional permissions for profile access.")
                        .font(.footnote).foregroundStyle(.secondary)
                    tokenEntry
                } else {
                    DisclosureGroup("Reconnect GitHub", isExpanded: $reconnecting) {
                        Text("Reconnecting clears widget access. Choose widgets again after connecting.")
                            .font(.footnote).foregroundStyle(.secondary)
                        tokenEntry
                    }
                }
                if model.busy { Button("Cancel") { token = ""; model.cancel() } }
                Link("Manage GitHub Tokens", destination: URL(string: "https://github.com/settings/personal-access-tokens")!)
                if model.connection != nil {
                    Button("Disconnect from This Device", role: .destructive) { token = ""; model.disconnect() }
                        .disabled(model.busy)
                }
            } header: { Text("GitHub") } footer: {
                Text("Your token stays in this device’s Keychain. Disconnecting removes it from ScriptWidget on this device; you can revoke the token on GitHub.")
            }
            if let connection = model.connection {
                Section {
                    ForEach(model.owners) { owner in
                        Toggle(owner.name, isOn: Binding(get: { connection.grantedOwners.contains(owner.id) }, set: { model.setGranted($0, owner: owner) }))
                            .disabled(model.busy || !model.ready)
                    }
                    if model.owners.isEmpty && model.ownerMessage == nil { Text("Install a widget to allow it to read this account.").foregroundStyle(.secondary) }
                    if let message = model.ownerMessage { Text(message).foregroundStyle(.secondary) }
                } header: { Text("Widgets with Profile Access") } footer: {
                    Text("Only the widgets you select can read this account’s profile. New and reinstalled widgets start without access.")
                }
            }
            ScriptWidgetSpotifyAccountSection(model: spotify, window: presentationWindow)
            if let message = model.message {
                Section {
                    Text(message.replacingOccurrences(of: #"^\[service_[a-z_]+\] "#, with: "", options: .regularExpression))
                        .foregroundStyle(.red).accessibilityIdentifier("service.github.error")
                    Button("Reload Account Settings") { token = ""; model.reload() }.disabled(model.busy)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Service Accounts")
        .background(ScriptWidgetServicePresentationWindow(reference: presentationWindow))
        .task(id: scenePhase) { if scenePhase == .active { model.reload(); spotify.reload() } }
        .onDisappear { token = ""; model.cancel(); spotify.cancel() }
    }

    private var tokenEntry: some View {
        Group {
            SecureField("GitHub personal access token", text: $token)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .disabled(model.busy)
                .accessibilityIdentifier("service.github.token")
            Button(model.busy ? "Connecting…" : model.connection == nil ? "Connect GitHub" : "Reconnect GitHub") {
                let value = token; token = ""; model.connectGitHub(token: value); reconnecting = false
            }
            .disabled(!model.ready || model.busy || token.isEmpty)
            .accessibilityIdentifier("service.github.connect")
        }
    }
}
