//
//  EditorWebView.swift
//  ScriptWidgetMac
//
//  Shared ScriptWidget Studio editor host.
//

import Combine
import SwiftUI
import WebKit

@MainActor final class EditorService {
    static let saveNotification = Notification.Name("EditorService_SaveNotification")
    fileprivate static let snapshotRequestNotification = Notification.Name("EditorService_SnapshotNotification")
    fileprivate static let replaceDocumentNotification = Notification.Name("EditorService_ReplaceDocumentNotification")

    static func save(target: StudioEditorTarget, completion: @escaping (Bool) -> Void) {
        let request = StudioEditorSaveRequest(target: target, completion: completion)
        NotificationCenter.default.post(name: saveNotification, object: request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { request.finish(false) }
    }

    static func requestSnapshot(target: StudioEditorTarget, completion: @escaping (StudioDocumentSnapshot?) -> Void) {
        let request = StudioEditorSnapshotRequest(target: target, completion: completion)
        NotificationCenter.default.post(name: snapshotRequestNotification, object: request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { request.finish(nil) }
    }

    static func replaceDocument(with content: String, snapshot: StudioDocumentSnapshot,
                                completion: @escaping (StudioDocumentApplyResult) -> Void) {
        let request = StudioEditorReplacementRequest(snapshot: snapshot, content: content, completion: completion)
        NotificationCenter.default.post(name: replaceDocumentNotification, object: request)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { request.finish(.unavailable) }
    }
}

typealias EditorDocumentSnapshot = StudioDocumentSnapshot

final class EditorInternalWebView: WKWebView {
    fileprivate var libraryEditorLease: UUID?
    private var bridge: WKWebViewJavascriptBridge?
    private var scriptModel: ScriptModel?
    private var currentRelativePath = "main.jsx"
    private var isEditorReady = false
    private var pendingActions: [() -> Void] = []
    private var cancellables = Set<AnyCancellable>()
    private var currentDocumentID: String?
    private var documentGeneration = UUID()
    private var requestedDocumentID: String?
    private let documentSession = StudioDocumentSession()
    private var isTearingDown = false
    private var hasLoadedEditor = false
    private var draftWorkItem: DispatchWorkItem?

    let editorID: UUID

    required init?(coder: NSCoder) {
        editorID = UUID()
        super.init(coder: coder)
    }

    init(editorID: UUID = UUID()) {
        self.editorID = editorID
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.setURLSchemeHandler(EditorSchemeHandler(), forURLScheme: kEditorURLScheme)
        super.init(frame: .zero, configuration: configuration)

        setValue(false, forKey: "drawsBackground")
        bridge = WKWebViewJavascriptBridge(webView: self)
        registerBridgeHandlers()

        NotificationCenter.default.publisher(for: EditorService.saveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, !self.isTearingDown,
                      let request = notification.object as? StudioEditorSaveRequest,
                      request.target.editorID == self.editorID else { return }
                guard request.target.documentID == self.currentDocumentID else { request.finish(false); return }
                self.saveCurrentContent(completion: request.finish)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: EditorService.snapshotRequestNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, !self.isTearingDown,
                      let request = notification.object as? StudioEditorSnapshotRequest,
                      request.target.editorID == self.editorID else { return }
                guard request.target.documentID == self.currentDocumentID else { request.finish(nil); return }
                self.readSnapshot(completion: request.finish)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: EditorService.replaceDocumentNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self, !self.isTearingDown,
                      let request = notification.object as? StudioEditorReplacementRequest,
                      request.snapshot.editorID == self.editorID else { return }
                self.replaceDocument(request)
            }
            .store(in: &cancellables)
    }

    func invalidate() {
        guard !isTearingDown else { return }
        if let documentID = currentDocumentID, isEditorReady {
            let sessionID = documentGeneration.uuidString
            let handoff = StudioDocumentHandoff.begin(documentID)
            let closingModel = scriptModel, relativePath = currentRelativePath
            let request = StudioEditorCloseRequest { [self] response in
                if let snapshot = StudioDocumentSnapshot(state: response),
                   snapshot.documentID == documentID, snapshot.sessionID == sessionID {
                    documentSession.bufferSnapshot(snapshot.content, version: snapshot.version)
                }
                if let model = closingModel, !model.package.readonly {
                    // A different window/iCloud edit wins over this closing
                    // view's old baseline. Keep its recovery draft instead.
                    if model.package.readFile(relativePath: relativePath).0 == documentSession.savedContent {
                        let saved = documentSession.save(documentSession.bufferedContent, documentID: documentID) { content in
                            let entry = model.package.readManifest()?.entry ?? "main.jsx"
                            return relativePath == entry
                                ? model.package.writeMainFile(content: content).0
                                : model.package.writeFile(relativePath: relativePath, content: content).0
                        }
                        if saved { NotificationCenter.default.post(name: PreviewService.updateNotification, object: model.package) }
                    } else {
                        documentSession.persistBufferedDraft()
                    }
                }
                StudioDocumentHandoff.finish(documentID, token: handoff)
            }
            // Retain the host through a bounded final snapshot even when
            // SwiftUI has already detached its representable.
            callStudio(handlerName: StudioProtocol.editorGetState, callback: request.finish)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { request.finish(nil) }
        }
        isTearingDown = true
        documentGeneration = UUID()
        pendingActions.removeAll()
        draftWorkItem?.cancel()
        for cancellable in cancellables { cancellable.cancel() }
        cancellables.removeAll()
    }

    deinit {
        ScriptWidgetEditorPresence.unregister(libraryEditorLease)
        stopLoading()
        draftWorkItem?.cancel()
        pendingActions.removeAll()
        bridge?.reset()
        bridge = nil
    }

    func loadEditorIfNeeded() {
        guard !hasLoadedEditor else { return }
        hasLoadedEditor = true
        load(URLRequest(url: editorWebServiceURL()))
    }

    func updateDocument(_ model: ScriptModel, relativePath: String) {
        guard !isTearingDown else { return }
        let resolvedRelativePath = relativePath.isEmpty ? "main.jsx" : relativePath
        guard let documentURL = model.package.resolvedPackageURL(relativePath: resolvedRelativePath) else { return }
        let documentID = documentURL.standardizedFileURL.path
        requestedDocumentID = documentID

        guard currentDocumentID != documentID else {
            scriptModel = model
            if isEditorReady {
                setReadOnly(model.package.readonly)
            }
            return
        }

        let activateDocument = { [weak self] in
            StudioDocumentHandoff.afterClosing(documentID) { [weak self] in
                guard let self, !self.isTearingDown, self.requestedDocumentID == documentID else { return }
                self.scriptModel = model
                self.currentRelativePath = resolvedRelativePath
                self.currentDocumentID = documentID
                self.documentGeneration = UUID()
                self.openCurrentDocument()
            }
        }

        runWhenReady { [weak self] in
            guard let self else { return }
            if self.currentDocumentID == nil {
                activateDocument()
            } else {
                self.saveCurrentContent { saved in
                    if saved { activateDocument() }
                }
            }
        }
    }

    private func registerBridgeHandlers() {
        bridge?.register(handlerName: StudioProtocol.ready) { [weak self] _, callback in
            guard let self else { return }
            if !isEditorReady {
                isEditorReady = true
                flushPendingActions()
            }
            callback?(["result": "ok", "protocolVersion": StudioProtocol.version])
        }

        bridge?.register(handlerName: StudioProtocol.documentSave) { [weak self] parameters, callback in
            guard
                let self,
                let payload = parameters?["payload"] as? [String: Any],
                let content = payload["content"] as? String,
                parameters?["documentID"] as? String == self.currentDocumentID,
                parameters?["sessionID"] as? String == self.documentGeneration.uuidString
            else {
                callback?(["result": "failed", "message": "Invalid document payload"])
                return
            }

            guard let version = payload["version"] as? Int,
                  self.documentSession.bufferSnapshot(content, version: version) else {
                callback?(["result": "failed"]); return
            }
            let saved = save(content: content)
            callback?(saved ? ["result": "ok"] : ["result": "failed"])
        }

        bridge?.register(handlerName: StudioProtocol.documentChanged) { [weak self] parameters, callback in
            guard let self, parameters?["documentID"] as? String == self.currentDocumentID,
                  parameters?["sessionID"] as? String == self.documentGeneration.uuidString else {
                callback?(["result": "failed"]); return
            }
            guard let payload = parameters?["payload"] as? [String: Any],
                  self.documentSession.bufferChange(payload) else {
                callback?(["result": "failed"]); return
            }
            self.scheduleDraftSnapshot()
            callback?(["result": "ok"])
        }

        bridge?.register(handlerName: StudioProtocol.documentResources) { [weak self] parameters, callback in
            guard let self, let id = self.currentDocumentID,
                  parameters?["documentID"] as? String == id,
                  parameters?["sessionID"] as? String == self.documentGeneration.uuidString, let model = self.scriptModel else {
                callback?(["result": "failed"]); return
            }
            callback?(["result": "ok", "documentID": id, "resources": model.package.editorImageResources()])
        }
    }

    private func openCurrentDocument() {
        guard let model = scriptModel else { return }
        let result = model.package.readFile(relativePath: currentRelativePath)
        guard let content = result.0 else { return }

        guard let currentDocumentID else { return }
        documentGeneration = UUID()
        let recovered = documentSession.open(documentID: currentDocumentID, content: content)
        callStudio(
            handlerName: StudioProtocol.documentOpen,
            payload: [
                "content": recovered,
                "dirty": recovered != content,
                "version": 0,
                "readOnly": model.package.readonly,
                "resources": model.package.editorImageResources(),
            ]
        )
    }

    private func scheduleDraftSnapshot() {
        draftWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isTearingDown else { return }
            self.documentSession.persistBufferedDraft()
        }
        draftWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func setReadOnly(_ readOnly: Bool) {
        callStudio(handlerName: StudioProtocol.documentSetReadOnly, payload: ["readOnly": readOnly])
    }

    private func saveCurrentContent(completion: @escaping (Bool) -> Void = { _ in }) {
        guard !isTearingDown, isEditorReady, let documentID = currentDocumentID else {
            completion(false)
            return
        }
        let generation = documentGeneration
        callStudio(handlerName: StudioProtocol.editorGetState) { [weak self] response in
            guard
                let self,
                !self.isTearingDown, self.documentGeneration == generation,
                let state = response as? [String: Any],
                let content = state["content"] as? String,
                self.currentDocumentID == documentID,
                state["documentID"] as? String == documentID,
                state["sessionID"] as? String == generation.uuidString,
                let version = state["version"] as? Int,
                self.documentSession.bufferSnapshot(content, version: version)
            else {
                completion(false)
                return
            }
            if self.scriptModel?.package.readonly == true {
                completion(content == self.documentSession.savedContent)
                return
            }
            let saved = save(content: content)
            completion(saved)
        }
    }

    private func readSnapshot(completion: @escaping (StudioDocumentSnapshot?) -> Void) {
        guard isEditorReady, !isTearingDown, let documentID = currentDocumentID else { completion(nil); return }
        let generation = documentGeneration
        callStudio(handlerName: StudioProtocol.editorGetState) { [weak self] response in
            guard let self, !self.isTearingDown, self.currentDocumentID == documentID,
                  self.documentGeneration == generation,
                  let snapshot = StudioDocumentSnapshot(state: response, editorID: self.editorID),
                  snapshot.documentID == documentID, snapshot.sessionID == generation.uuidString,
                  self.documentSession.bufferSnapshot(snapshot.content, version: snapshot.version) else {
                completion(nil); return
            }
            completion(snapshot)
        }
    }

    private func replaceDocument(_ request: StudioEditorReplacementRequest) {
        guard request.isPending else { return }
        guard isEditorReady, !isTearingDown else { request.finish(.unavailable); return }
        let snapshot = request.snapshot
        guard snapshot.documentID == currentDocumentID,
              snapshot.sessionID == documentGeneration.uuidString,
              scriptModel?.package.readonly == false else { request.finish(.conflict); return }
        let generation = documentGeneration
        callStudio(handlerName: StudioProtocol.documentReplace,
                   payload: ["content": request.content, "expectedContent": snapshot.content, "version": snapshot.version + 1]) { [weak self] response in
            guard let self, request.isPending else { return }
            guard !self.isTearingDown, self.documentGeneration == generation,
                  self.currentDocumentID == snapshot.documentID else { request.finish(.conflict); return }
            guard (response as? [String: Any])?["result"] as? String == "ok" else {
                request.finish(.conflict); return
            }
            // Read current text so newer manual edits survive a delayed reply.
            self.saveCurrentContent { saved in request.finish(saved ? .saved : .saveFailed) }
        }
    }

    @discardableResult
    private func save(content: String) -> Bool {
        guard !isTearingDown, let scriptModel, !scriptModel.package.readonly, let documentID = currentDocumentID else { return false }
        let saved = documentSession.save(content, documentID: documentID) { value in
            let entry = scriptModel.package.readManifest()?.entry ?? "main.jsx"
            return currentRelativePath == entry
                ? scriptModel.package.writeMainFile(content: value).0
                : scriptModel.package.writeFile(relativePath: currentRelativePath, content: value).0
        }
        guard saved else { return false }

        NotificationCenter.default.post(name: PreviewService.updateNotification, object: scriptModel.package)
        return true
    }

    private func runWhenReady(_ action: @escaping () -> Void) {
        if isEditorReady {
            DispatchQueue.main.async(execute: action)
        } else {
            pendingActions.append(action)
        }
    }

    private func flushPendingActions() {
        let actions = pendingActions
        pendingActions.removeAll()
        actions.forEach { $0() }
    }

    private func studioEnvelope(type: String, payload: [String: Any]) -> [String: Any] {
        StudioProtocol.envelope(type: type, documentID: currentDocumentID, payload: payload, sessionID: documentGeneration.uuidString)
    }

    private func callStudio(
        handlerName: String,
        payload: [String: Any] = [:],
        callback: ((Any?) -> Void)? = nil
    ) {
        bridge?.call(
            handlerName: handlerName,
            data: studioEnvelope(type: handlerName, payload: payload),
            callback: callback
        )
    }
}

struct EditorWebView: NSViewRepresentable {
    let scriptModel: ScriptModel
    let relativePath: String
    var editorID = UUID()

    func makeNSView(context: Context) -> EditorInternalWebView {
        let webView = EditorInternalWebView(editorID: editorID)
        webView.libraryEditorLease = ScriptWidgetEditorPresence.register()
        webView.loadEditorIfNeeded()
        webView.updateDocument(scriptModel, relativePath: relativePath)
        return webView
    }

    static func dismantleNSView(_ view: EditorInternalWebView, coordinator: ()) {
        ScriptWidgetEditorPresence.unregister(view.libraryEditorLease)
        view.libraryEditorLease = nil
        view.invalidate()
    }

    func updateNSView(_ view: EditorInternalWebView, context: Context) {
        view.updateDocument(scriptModel, relativePath: relativePath)
    }
}

struct EditorWebView_Previews: PreviewProvider {
    static var previews: some View {
        EditorWebView(scriptModel: globalScriptModel, relativePath: "main.jsx")
    }
}
