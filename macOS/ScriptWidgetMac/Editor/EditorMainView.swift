//
//  EditorView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//

import SwiftUI

struct EditorMainView: View {
    
    @SceneStorage("editorPanelLayoutMode") var panelLayoutModeVertical = true
    
    let scriptModel: ScriptModel
    
    init(scriptModel: ScriptModel) {
        self.scriptModel = scriptModel
    }
    
    var body: some View {
        content
            .navigationTitle("ScriptWidget - \(scriptModel.name)")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        panelLayoutModeVertical.toggle()
                    }) {
                        if panelLayoutModeVertical {
                            Image(systemName: "align.horizontal.left")
                        } else {
                            Image(systemName: "align.vertical.top")
                        }
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    ButtonOfficalSite()
                }
            }
    }
    
    var content: some View {
        Group {
            if panelLayoutModeVertical {
                HSplitView {
                    EditorWebView(scriptModel: scriptModel)
                        .frame(idealWidth:600)
                    
                    EditorPanelView(scriptModel: scriptModel)
                        .frame(minWidth: 280, maxWidth: 380)
                        .frame(idealHeight: 380)
                }
            } else {
                VSplitView {
                    EditorWebView(scriptModel: scriptModel)
                        .frame(idealHeight: 600)
                    
                    EditorPanelView(scriptModel: scriptModel)
                        .frame(minHeight: 300)
                        .frame(idealHeight: 400)
                }
            }
        }
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorMainView(scriptModel: globalScriptModel)
    }
}
