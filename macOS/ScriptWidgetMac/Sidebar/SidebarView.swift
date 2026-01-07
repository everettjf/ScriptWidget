//
//  SidebarView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//

import SwiftUI




struct SidebarView: View {
    @ObservedObject var store: SharedAppStore
    // create
    @State private var createShowingSheet = false
    
    // rename
    @State private var renameCurrentName = ""
    @State private var renameInputName = ""
    @State private var renameShowingSheet = false
    
    // delete
    @State private var deleteCurrentName = ""
    @State private var deleteShowingSheet = false
    
    
    var body: some View {
        content
            .frame(minWidth:200, maxWidth: 300, idealHeight: 250)
            .sheet(isPresented: $renameShowingSheet) {
                RenameConfirmView(currentName: $renameCurrentName, inputName: $renameInputName)
            }
            .sheet(isPresented: $deleteShowingSheet) {
                DeleteConfirmView(currentName: $deleteCurrentName)
            }
            .sheet(isPresented: $createShowingSheet) {
                CreateGuideView()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button{
                        MacKitUtil.toggleSidebar()
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        self.createShowingSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
    }
    
    @ViewBuilder
    var content: some View {
        List {
            Section("Scripts") {
                if store.scriptModels.isEmpty {
                    EmptyListBackgroundView()
                } else {
                    ForEach(store.scriptModels) { item in
                        NavigationLink(destination: EditorMainView(scriptModel: item)) {
                            WidgetRowView(model: item)
                                .padding(.vertical, 2)
                        }
                        .contextMenu(menuItems: {
                            Button("Reveal in Finder") {
                                MacKitUtil.revealInFinder(item.package.path.path)
                            }
                            Button("Update") {
                                item.package.updateFiles()
                            }
                            Button("Rename") {
                                self.renameCurrentName = item.name
                                self.renameInputName = item.name
                                self.renameShowingSheet.toggle()
                            }
                            Button("Delete") {
                                self.deleteCurrentName = item.name
                                self.deleteShowingSheet.toggle()
                            }
                            
                            Button("Import") {
                                MacKitUtil.selectFile(title: "Import script") { path in
                                    guard let path = path else {
                                        return
                                    }
                                    print("try import path : \(path)")
                                    let result = sharedScriptManager.importScript(fromPath: path)
                                    if result {
                                        MacKitUtil.alertInfo(title: "", message: "Succeed import :)")
                                    } else {
                                        MacKitUtil.alertWarn(title: "", message: "Failed import, please retry ~")
                                    }
                                    
                                    NotificationCenter.default.post(name: SharedAppStore.scriptCreateNotification, object: nil)
                                }
                            }
                            
                            Button("Export") {
                                MacKitUtil.selectDirectory(title: "Export to") { path in
                                    guard let path = path else {
                                        return
                                    }
                                    let exportFilePath = path.appendingPathComponent(item.exportFileName)
                                    let result = sharedScriptManager.exportScript(model: item, toPath: exportFilePath)
                                    if result {
                                        MacKitUtil.alertInfo(title: "", message: "Succeed export :)")
                                    } else {
                                        MacKitUtil.alertWarn(title: "", message: "Failed export, please retry ~")
                                    }
                                }
                            }
                        })
                    }
                }
            }
            Section("Resources") {
                NavigationLink(destination: ResourceCodeView(resourceType: "api")) {
                    Label("APIs", systemImage: "scribble.variable")
                }
                NavigationLink(destination: ResourceCodeView(resourceType: "component")) {
                    Label("Components", systemImage: "scribble.variable")
                }
                NavigationLink(destination: ResourceCodeView(resourceType: "template")) {
                    Label("Templates", systemImage: "scribble.variable")
                }
            }
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(store: SharedAppStore())
    }
}
