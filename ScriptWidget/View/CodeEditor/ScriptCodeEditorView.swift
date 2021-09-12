//
//  ScriptCodeEditorView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI
import SwiftUIX

enum ScriptCodeEditorViewMode {
    case creator
    case editor
}

struct ScriptCodeEditorNavButtonView: View {
    let image: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: image)
                    .font(.title3)
                
                Text(text.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
    }
}

class ScriptCodeEditorViewDataObject : ObservableObject {

    @Published var scriptModel: ScriptModel

    init(scriptModel: ScriptModel) {
        self.scriptModel = scriptModel
        
        NotificationCenter.default.addObserver(forName: ScriptWidgetListViewDataObject.scriptRenameNotification, object: nil, queue: OperationQueue.main) { (noti) in

            guard let newName = noti.userInfo?["newName"] as? String else { return }
            
            self.scriptModel = sharedScriptManager.getScript(scriptId: newName)
         
            NotificationCenter.default.post(name: CodeEditorViewController.changeFileNotification, object: nil, userInfo: ["file": self.scriptModel.file])
        }
    }
}

struct ScriptCodeEditorView: View {
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var dataObject: ScriptCodeEditorViewDataObject
    let mode: ScriptCodeEditorViewMode
    let actionCreate: (() -> Void)?

    @State var showRunnerView = false
    @State var showEditAttributesView = false
    @State var showShareActivity: Bool = false

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
    
    var body: some View {
        VStack {
            CodeEditorInternalView(file: self.dataObject.scriptModel.file)
                .navigationBarTitle(self.dataObject.scriptModel.name, displayMode: .inline)
                .navigationBarItems(
                    leading: HStack {
                        if self.mode != .creator {
                            ScriptCodeEditorNavButtonView(image: "pencil.circle", text: "Edit") {
                                self.showEditAttributesView.toggle()
                            }
                            .fullScreenCover(isPresented: $showEditAttributesView, content: {
                                EditAttributesView(scriptModel: self.dataObject.scriptModel) {
                                    self.presentationMode.wrappedValue.dismiss()
                                }
                            })
                        }
                    },
                    trailing: HStack {
                        
                        ScriptCodeEditorNavButtonView(image: "square.and.arrow.up", text: "Share") {
                            self.showShareActivity.toggle()
                        }
                        .sheet(isPresented: $showShareActivity, content: {
                            AppActivityView(activityItems: [self.dataObject.scriptModel.file.fileURL])
                        })
                        
                        ScriptCodeEditorNavButtonView(image: "play", text: "Play") {
                            self.showRunnerView.toggle()
                        }
                        .fullScreenCover(isPresented: $showRunnerView, content: {
                            ScriptCodeRunnerView(file: self.dataObject.scriptModel.file)
                        })
                        
                        if self.mode == .creator {
                            ScriptCodeEditorNavButtonView(image: "plus.square", text: "Create") {
                                print("create tapped")
                                
                                if let action = self.actionCreate {
                                    action()
                                }
                            }
                        }
                    }
                )
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
