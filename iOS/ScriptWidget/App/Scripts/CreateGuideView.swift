//
//  CreateGuideView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/1/3.
//

import SwiftUI


class CreateGuideDataObject: ObservableObject {
    @Published var models = [ScriptModel]()

    init() {
        
        
        DispatchQueue.global().async { [self] in
            var items = ScriptManager.listBundleScripts(bundle: "Script", relativePath: "template")
            if let index = items.firstIndex(where: { (model) -> Bool in
                return model.name == "Empty Script"
            }) {
                items.move(fromOffsets: [index], toOffset: 0)
            }
            
            DispatchQueue.main.async {
                self.models = items
            }
        }
        
    }
}


struct CreateGuideView: View {
    @ObservedObject var dataObject = CreateGuideDataObject()
    
    @Environment(\.presentationMode) var presentationMode
        
    var body: some View {
        NavigationView {
            List {
                ForEach(dataObject.models) { item in
                    NavigationLink(destination: ScriptCodeEditorView(mode: .creator,scriptModel:item, actionCreate: {
                        // create
                        guard let content = item.package.readMainFile().0 else { return }
                        
                        // image copy path
                        let imageCopyPath = item.package.imagePath
                        
                        _ = sharedScriptManager.createScript(content: content, recommendPackageName: item.name, imageCopyPath: imageCopyPath)
                        
                        NotificationCenter.default.post(name: ScriptWidgetHomeViewDataObject.scriptCreateNotification, object: nil)
                        
                        // dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                            self.presentationMode.wrappedValue.dismiss()
                        })
                    })) {
                        WidgetRowView(model: item)
                    }
                }
            }
            .navigationBarTitle(Text("Create from template"), displayMode: .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

struct CreateGuideView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGuideView()
    }
}
