//
//  ScriptCodeEditorView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI

enum ScriptCodeEditorViewMode {
    case creator
    case editor
}

struct ScriptCodeEditorNavButtonView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .accessibilityLabel(Text(title))
    }
}


class ScriptCodeEditorViewDataObject : ObservableObject {
    let editorID = UUID()
    
    @Published var scriptModel: ScriptModel
    @Published var filePath: URL
    private var renameObserver: NSObjectProtocol?
    
    init(scriptModel: ScriptModel) {
        self.scriptModel = scriptModel
        self.filePath = scriptModel.package.jsxPath
        
        renameObserver = NotificationCenter.default.addObserver(forName: ScriptWidgetHomeViewDataObject.scriptRenameNotification, object: nil, queue: OperationQueue.main) { [weak self] noti in
            
            guard let self, let newName = noti.userInfo?["newName"] as? String,
                  let oldName = noti.userInfo?["oldName"] as? String,
                  self.scriptModel.name == oldName else { return }
            let oldRoot = self.scriptModel.package.path.standardizedFileURL.path + "/"
            let oldFile = self.filePath.standardizedFileURL.path
            let relative = oldFile.hasPrefix(oldRoot) ? String(oldFile.dropFirst(oldRoot.count)) : "main.jsx"
            let package = sharedScriptManager.getScriptPackage(packageName: newName)
            self.scriptModel = ScriptModel(package: package)
            self.filePath = package.resolvedPackageURL(relativePath: relative) ?? package.jsxPath
        }
    }

    deinit {
        if let renameObserver {
            NotificationCenter.default.removeObserver(renameObserver)
        }
    }
}

struct ScriptCodeEditorView: View {
    @StateObject private var dataObject: ScriptCodeEditorViewDataObject
    let mode: ScriptCodeEditorViewMode
    let actionCreate: (() -> Void)?
    
    @State private var showRunnerView = false
    @State private var showResourceCodeView = false
    @State private var showCopilotView = false
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var didSave = false
    @State private var isSaving = false

    // The detail column can be much narrower than a regular size class suggests,
    // especially when an unfolded display keeps the widget list visible.
    private let minimumInlinePanelWidth: CGFloat = 800

    
    init(mode: ScriptCodeEditorViewMode, scriptModel: ScriptModel) {
        self.mode = mode
        _dataObject = StateObject(wrappedValue: ScriptCodeEditorViewDataObject(scriptModel: scriptModel))
        self.actionCreate = nil
    }
    
    init(mode: ScriptCodeEditorViewMode, scriptModel: ScriptModel, actionCreate: @escaping () -> Void) {
        self.mode = mode
        _dataObject = StateObject(wrappedValue: ScriptCodeEditorViewDataObject(scriptModel: scriptModel))
        self.actionCreate = actionCreate
    }
    
    var codeeditor: some View {
        ScriptPackageEditorView(model: dataObject.scriptModel, filePath: $dataObject.filePath, editorID: dataObject.editorID)
            .onDisappear {
                MirrorEditorService.save(target: StudioEditorTarget(editorID: dataObject.editorID, documentID: dataObject.filePath.standardizedFileURL.path)) { _ in }
            }
    }
    
    func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    var body: some View {
        GeometryReader { proxy in
            let showsInlinePanel = proxy.size.width >= minimumInlinePanelWidth

            HStack(spacing: 0) {
                codeeditor
                    .frame(width: showsInlinePanel ? proxy.size.width * 0.58 : proxy.size.width)
                if showsInlinePanel {
                    Divider()
                    ScriptCodeStudioPanelView(
                        scriptModel: dataObject.scriptModel,
                        filePath: $dataObject.filePath,
                        editorID: dataObject.editorID
                    )
                }
            }
            .navigationTitle(self.dataObject.scriptModel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingButtons
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingButtons(showsInlinePanel: showsInlinePanel)
                }
            }
            .ignoresSafeArea(.all, edges: .bottom)
            .alert("Notification", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showCopilotView) {
                NavigationStack {
                    ScriptCodeCopilotView(scriptModel: dataObject.scriptModel, editorID: dataObject.editorID, documentID: dataObject.filePath.standardizedFileURL.path)
                        .navigationTitle("AI Copilot")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showCopilotView = false }
                            }
                        }
                }
            }
        }
    }
    
    var leadingButtons: some View {
        HStack {
            if self.mode != .creator  {
                ScriptCodeEditorNavButtonView(title: "Project Resources", systemImage: "book.closed") {
                    self.showResourceCodeView.toggle()
                }
                .sheet(isPresented: $showResourceCodeView, content: {
                    ResourceCodeView(model: dataObject.scriptModel)
                })
            }
        }
    }
    
    var previewView: some View {
        ScriptCodePreviewView(model: dataObject.scriptModel, filePath: $dataObject.filePath)
    }
    
    func trailingButtons(showsInlinePanel: Bool) -> some View {
        HStack {
            if mode == .editor, #available(iOS 16.2, *) {
                ScriptCodeEditorNavButtonView(title: "Start Live Activity", systemImage: "lock.rectangle") {
                    saveEditor {
                        let package = dataObject.scriptModel.package
                        isSaving = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            let expected=(try? ScriptWidgetLiveActivityBinding.capture(name:package.name,cacheOnly:false))?.0
                            let result = sharedScriptManager.buildScriptPackage(package: package, requireSharedContainer: true)
                            DispatchQueue.main.async {
                                isSaving = false
                                guard result.0 else { showAlert(result.1); return }
                                guard let expected,expected.ownerID==package.managedScope?.binding?.ownerID,
                                      (try? package.managedScope?.validate(name:package.name)) != nil else { showAlert("This widget installation changed. Reopen it and try again.");return }
                                if sharedLiveActivityManager.create(scriptName: package.name, scriptParameter: "",expectedBinding:expected) != nil {
                                    showAlert("Lock screen live activity created.")
                                } else {
                                    showAlert(sharedLiveActivityManager.message ?? "Live Activity could not be started. Check device support and Settings.")
                                }
                            }
                        }
                    }
                }
                .disabled(isSaving)
            }

            ScriptCodeEditorNavButtonView(title: "Run Preview", systemImage: "play.fill") {
                self.showRunnerView.toggle()
            }
            .keyboardShortcut("r", modifiers: .command)
            .sheet(isPresented: $showRunnerView, content: {
                previewView
            })

            if mode == .editor && !showsInlinePanel {
                ScriptCodeEditorNavButtonView(title: "AI Copilot", systemImage: "sparkles") {
                    showCopilotView = true
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }

            if mode == .editor {
                Button {
                    saveEditor {}
                } label: {
                    Label(didSave ? "Saved" : "Save", systemImage: didSave ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .disabled(isSaving)
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityLabel(didSave ? "Widget saved" : "Save widget")
                .foregroundStyle(didSave ? Color.green : Color.accentColor)
            }
            
            if self.mode == .creator {
                ScriptCodeEditorNavButtonView(title: "Create Widget", systemImage: "plus.square.fill") {
                    print("create tapped")
                    
                    DispatchQueue.main.async {
                        if let action = self.actionCreate {
                            action()
                        }
                    }
                }
            }
        }
    }

    private func saveEditor(onSuccess: @escaping () -> Void) {
        guard !isSaving else { return }
        isSaving = true
        didSave = false
        MirrorEditorService.save(target: StudioEditorTarget(editorID: dataObject.editorID, documentID: dataObject.filePath.standardizedFileURL.path)) { succeeded in
            isSaving = false
            guard succeeded else {
                showAlert("Could not save the script. Your edits are still in the editor. Try saving again before leaving.")
                return
            }
            withAnimation(.easeOut(duration: 0.2)) { didSave = true }
            onSuccess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { didSave = false }
        }
    }

}

private struct ScriptCodeStudioPanelView: View {
    let scriptModel: ScriptModel
    @Binding var filePath: URL
    let editorID: UUID
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Studio panel", selection: $selectedTab) {
                Label("Preview", systemImage: "play.rectangle").tag(0)
                Label("Copilot", systemImage: "sparkles").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                ScriptCodePreviewView(model: scriptModel, filePath: $filePath, showsCloseButton: false)
            } else {
                ScriptCodeCopilotView(scriptModel: scriptModel, editorID: editorID, documentID: filePath.standardizedFileURL.path)
            }
        }
        .background(StudioDesign.groupedBackground)
    }
}

private struct ScriptCodeCopilotView: View {
    let scriptModel: ScriptModel
    let editorID: UUID
    let documentID: String?
    @State private var proposalSnapshot: StudioDocumentSnapshot?
    @State private var requestID = UUID()
    @State private var isApplying = false
    @State private var isReading = false

    @StateObject private var session = AIGenerateSession()
    @State private var instruction = ""
    @State private var originalCode = ""
    @State private var proposedCode = ""
    @State private var statusMessage: String?
    @State private var selectedSkillIDs: Set<String> = []
    @State private var skills: [AIWidgetSkill] = AIWidgetSkills.builtIns
    @State private var showingOriginal = false
    @State private var showingProposal = true

    private var changeSummary: AICopilotChangeSummary {
        .compare(original: originalCode, proposed: proposedCode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ask Studio for a focused change. The current code and latest runtime diagnostic are included, then the proposal is validated locally.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextEditor(text: $instruction)
                    .frame(minHeight: 100)
                    .padding(4)
                    .background(StudioDesign.cardBackground, in: .rect(cornerRadius: StudioDesign.controlCornerRadius))
                    .accessibilityLabel("Copilot instruction")

                Text("Skills")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], alignment: .leading, spacing: 8) {
                    ForEach(skills) { skill in
                        Toggle(isOn: skillBinding(skill.id)) {
                            Label(skill.title, systemImage: skill.symbol)
                                .font(.caption)
                        }
                        .toggleStyle(.button)
                        .accessibilityHint(skill.summary)
                    }
                }

                HStack {
                    Button("Propose Change", systemImage: "wand.and.stars") {
                        beginCopilotRequest(fixCurrentError: false)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Fix Error", systemImage: "wrench.and.screwdriver") {
                        beginCopilotRequest(fixCurrentError: true)
                    }
                }
                .disabled(session.isRunning || isReading || isApplying || scriptModel.package.readonly)

                if session.isRunning {
                    AIGenerateProgressView(session: session)
                    Button("Cancel", role: .cancel) { session.cancel() }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !proposedCode.isEmpty {
                    proposalReview
                }
            }
            .padding()
        }
        .onReceive(session.$phase) { phase in
            consume(phase: phase)
        }
        .onChange(of: documentID) { _ in resetProposal() }
        .onDisappear { resetProposal() }
        .onAppear { skills = AIWidgetSkillManager.shared.allSkills() }
        .onReceive(NotificationCenter.default.publisher(for: AIWidgetSkillManager.changedNotification)) { _ in
            skills = AIWidgetSkillManager.shared.allSkills()
        }
    }

    private var proposalReview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Review Proposal").font(.headline)
                Spacer()
                Text("\(changeSummary.changedLines) changed lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("Original · \(changeSummary.originalLines) lines", isExpanded: $showingOriginal) {
                codeBlock(originalCode)
            }
            DisclosureGroup("Proposed · \(changeSummary.proposedLines) lines", isExpanded: $showingProposal) {
                codeBlock(proposedCode)
            }
            HStack {
                Button("Reject", role: .destructive) {
                    proposedCode = ""
                    statusMessage = "Proposal rejected; the editor was not changed."
                }
                Spacer()
                Button("Apply", systemImage: "checkmark") {
                    applyProposal()
                }
                .buttonStyle(.borderedProminent)
            }
            .disabled(isApplying || proposalSnapshot == nil)
        }
    }

    private func codeBlock(_ code: String) -> some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .frame(maxHeight: 190)
        .background(StudioDesign.cardBackground, in: .rect(cornerRadius: StudioDesign.controlCornerRadius))
    }

    private func resetProposal() {
        requestID = UUID()
        proposalSnapshot = nil
        proposedCode = ""
        isApplying = false
        isReading = false
        statusMessage = nil
        session.cancel()
    }

    private func applyProposal() {
        guard !isApplying, let snapshot = proposalSnapshot else { return }
        let code = proposedCode, token = requestID
        isApplying = true
        statusMessage = "Applying and saving…"
        MirrorEditorService.replaceDocument(with: code, snapshot: snapshot) { result in
            guard requestID == token else { return }
            isApplying = false
            statusMessage = result.message
            if result == .saved {
                originalCode = code
                proposedCode = ""
                proposalSnapshot = nil
            }
        }
    }

    private func beginCopilotRequest(fixCurrentError: Bool) {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnostic = ScriptCodePreviewDiagnosticStore.shared.diagnostic(for: scriptModel.package.path)
        let requestText: String
        if fixCurrentError {
            requestText = trimmed.isEmpty ? "Fix the current runtime error while preserving the widget design." : trimmed
        } else {
            guard !trimmed.isEmpty else {
                statusMessage = "Describe the change you want first."
                return
            }
            requestText = trimmed
        }

        guard !isReading, !isApplying, let documentID else { return }
        let token = UUID()
        requestID = token
        isReading = true
        MirrorEditorService.requestSnapshot(target: StudioEditorTarget(editorID: editorID, documentID: documentID)) { snapshot in
            guard requestID == token else { return }
            isReading = false
            guard let snapshot else {
                statusMessage = "The editor is not ready yet."
                return
            }
            proposalSnapshot = snapshot
            originalCode = snapshot.content
            proposedCode = ""
            statusMessage = diagnostic == nil && fixCurrentError
                ? "No current runtime error was recorded; asking AI to inspect the code."
                : nil
            session.copilot(
                currentCode: snapshot.content,
                instruction: AIWidgetSkills.augment(requestText, selectedIDs: selectedSkillIDs),
                runtimeDiagnostic: diagnostic
            )
        }
    }

    private func consume(phase: AIGenerateSession.Phase) {
        guard proposalSnapshot != nil else { return }
        switch phase {
        case .done(let jsx):
            proposedCode = jsx
            statusMessage = "Proposal passed the local ScriptWidget runtime."
        case .exhausted(let lastJSX, let error):
            proposedCode = lastJSX ?? ""
            statusMessage = "Iteration limit reached: \(error ?? "unknown runtime error")"
        case .failed(let message):
            statusMessage = message
        case .cancelled:
            statusMessage = "Request cancelled."
        default:
            break
        }
    }

    private func skillBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedSkillIDs.contains(id) },
            set: { enabled in
                if enabled { selectedSkillIDs.insert(id) }
                else { selectedSkillIDs.remove(id) }
            }
        )
    }
}

#Preview("Widget Editor") {
    NavigationStack {
        ScriptCodeEditorView(mode: .editor, scriptModel: globalScriptModel)
    }
}
