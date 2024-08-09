//
//  ScriptListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/8.
//

import SwiftUI

class BundleScriptDataObject : ObservableObject {
    let bundleName: String
    let bundleDirectory: String
    
    @Published var models = [ScriptModel]()
    
    init(bundleName: String, bundleDirectory: String) {
        self.bundleName = bundleName
        self.bundleDirectory = bundleDirectory
        
        DispatchQueue.global().async { [self] in
            let items = ScriptManager.listBundleScripts(bundle: bundleName, relativePath: bundleDirectory)
            DispatchQueue.main.async {
                self.models = items
            }
        }
    }
}

struct BundleScriptListView: View {
    
    let navigationTitle: String
    let inlineTitle: Bool
    @ObservedObject var dataObject : BundleScriptDataObject
    
    let onNextAppear: () -> Void
    let onNextDisappear: () -> Void
    
    init(navigationTitle: String, inlineTitle: Bool, dataObject: BundleScriptDataObject, onNextAppear: @escaping () -> Void, onNextDisappear: @escaping () -> Void) {
        self.navigationTitle = navigationTitle
        self.inlineTitle = inlineTitle
        self.dataObject = dataObject
        self.onNextAppear = onNextAppear
        self.onNextDisappear = onNextDisappear
    }
    
    init(navigationTitle: String, inlineTitle: Bool, dataObject: BundleScriptDataObject) {
        self.navigationTitle = navigationTitle
        self.inlineTitle = inlineTitle
        self.dataObject = dataObject
        self.onNextAppear = {}
        self.onNextDisappear = {}
    }
    var body: some View {
        VStack {
            List {
                ForEach(dataObject.models) {item in
                    NavigationLink(destination:
                                    ScriptCodeEditorView(mode: .editor,scriptModel: item)
                        .onAppear { self.onNextAppear() }     // !!
                        .onDisappear { self.onNextDisappear() } // !!
                    ) {
                        HStack {
                            NameAutoImageView(name: item.name, colors: getGradientColorsWithString(string: item.name), size: 40)
                            
                            Text(item.name)
                                .font(.body)
                        }
                        
                    }
                }
            }
        }
        .navigationBarTitle(Text(LocalizedStringKey(navigationTitle)), displayMode: inlineTitle ? .inline : .automatic)
    }
}

struct ScriptListView_Previews: PreviewProvider {
    static var previews: some View {
        BundleScriptListView(navigationTitle: "API", inlineTitle: false, dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "api"))
    }
}
