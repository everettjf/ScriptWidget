//
//  ScriptCodeEditorView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI
import AlertToast

enum ScriptCodeEditorViewMode {
    case creator
    case editor
}

struct ScriptCodeEditorNavButtonView: View {
    let image: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: image)
                .font(.title3)
        }
    }
}


class ScriptCodeEditorViewDataObject : ObservableObject {
    
    @Published var scriptModel: ScriptModel
    @Published var filePath: URL
    
    init(scriptModel: ScriptModel) {
        self.scriptModel = scriptModel
        self.filePath = scriptModel.package.jsxPath
        
        NotificationCenter.default.addObserver(forName: ScriptWidgetHomeViewDataObject.scriptRenameNotification, object: nil, queue: OperationQueue.main) { (noti) in
            
            guard let newName = noti.userInfo?["newName"] as? String else { return }
            
            self.scriptModel = ScriptModel(package:sharedScriptManager.getScriptPackage(packageName: newName))
        }
    }
}

struct ScriptCodeEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var dataObject: ScriptCodeEditorViewDataObject
    let mode: ScriptCodeEditorViewMode
    let actionCreate: (() -> Void)?
    
    @State var name: String = ""
    
    @State var showRunnerView = false
    @State var showEditAttributesView = false
    @State var showShareActivity = false
    @State var showResourceCodeView = false
    
    @State var showingToast = false
    @State var toastMessage = ""

    
    init(mode: ScriptCodeEditorViewMode, scriptModel: ScriptModel) {
        self.mode = mode
        self.dataObject = ScriptCodeEditorViewDataObject(scriptModel: scriptModel)
        self.actionCreate = nil
    }
    
    init(mode: ScriptCodeEditorViewMode, scriptModel: ScriptModel, actionCreate: @escaping () -> Void) {
        self.mode = mode
        self.dataObject = ScriptCodeEditorViewDataObject(scriptModel: scriptModel)
        self.actionCreate = actionCreate
    }
    
    var codeeditor: some View {
        ScriptPackageEditorView(model: dataObject.scriptModel, filePath: $dataObject.filePath)
            .onDisappear {
                NotificationCenter.default.post(name: MirrorEditorService.saveNotification, object: nil)
            }
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        showingToast.toggle()
    }
    
    var body: some View {
        VStack {
            codeeditor
                .navigationBarTitle(self.dataObject.scriptModel.name, displayMode: .inline)
                .navigationBarItems(
                    leading: leadingButtons,
                    trailing: trailingButtons
                )
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .toast(isPresenting: $showingToast) {
            AlertToast(type: .regular, title: toastMessage)
        }
        
    }
    
    var leadingButtons: some View {
        HStack {
            if self.mode != .creator  {
                ScriptCodeEditorNavButtonView(image: "book") {
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
    
    var trailingButtons: some View {
        HStack {
            if #available(iOS 16.1, *) {
                ScriptCodeEditorNavButtonView(image: "lock") {
                    
                    // build
                    let buildResult = sharedScriptManager.buildScriptPackage(package: self.dataObject.scriptModel.package)
                    print("build result = \(buildResult)")
                    
                    // show lock screen widget
                    sharedLiveActivityManager.create(scriptName: self.dataObject.scriptModel.name, scriptParameter: "")
                    showToast("Lock screen live activity created :)")
                }
            }
            
            ScriptCodeEditorNavButtonView(image: "play") {
                self.showRunnerView.toggle()
            }
            .sheet(isPresented: $showRunnerView, content: {
                previewView
            })
            
            if self.mode == .creator {
                ScriptCodeEditorNavButtonView(image: "plus.square") {
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
}

struct ScriptCodeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScriptCodeEditorView(mode: .editor, scriptModel: globalScriptModel)
        }
    }
}
