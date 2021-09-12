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
            let bundle = ScriptWidgetBundle(bundle: bundleName)
            let items = bundle.listScripts(relativePath: bundleDirectory)
            DispatchQueue.main.async {
                self.models = items
            }
        }
    }
}

struct BundleScriptListView: View {
    
    let navigationTitle: String
    
    @ObservedObject var dataObject : BundleScriptDataObject
    
    
    var body: some View {
        VStack {
            List {
                ForEach(dataObject.models) {item in
                    NavigationLink(destination: ScriptCodeEditorView(mode: .editor,scriptModel: item)
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
        .navigationBarTitle(navigationTitle, displayMode: .inline)
    }
}

struct ScriptListView_Previews: PreviewProvider {
    static var previews: some View {
        BundleScriptListView(navigationTitle: "Snippet", dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "snippet"))
    }
}
