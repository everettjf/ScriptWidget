//
//  ResourceCodeView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/29.
//

import SwiftUI
class ResourceCodeStore : ObservableObject {
    
    @Published var apiModels = [ScriptModel]()
    @Published var componentModels = [ScriptModel]()
    @Published var templateModels = [ScriptModel]()
    
    
    init() {
        reloadBundleScripts()
    }
    
    func reloadBundleScripts() {
        
        DispatchQueue.global().async { [self] in
            let items = ScriptManager.listBundleScripts(bundle: "Script", relativePath: "api")
            DispatchQueue.main.async {
                self.apiModels = items
            }
        }
        DispatchQueue.global().async { [self] in
            let items = ScriptManager.listBundleScripts(bundle: "Script", relativePath: "component")
            DispatchQueue.main.async {
                self.componentModels = items
            }
        }
        DispatchQueue.global().async { [self] in
            let items = ScriptManager.listBundleScripts(bundle: "Script", relativePath: "template")
            DispatchQueue.main.async {
                self.templateModels = items
            }
        }
    }
}

struct ResourceCodeNavigationLink: View {
    
    let item: ScriptModel
    
    var body: some View {
        NavigationLink(destination: EditorMainView(scriptModel: item)) {
            WidgetRowView(model: item)
                .padding(.vertical, 2)
        }
        .contextMenu {
            Button("Reveal in Finder") {
                MacKitUtil.revealInFinder(item.package.path.path)
            }
        }
    }

}


struct ResourceCodeListView : View {
    
    let resourceType: String
    @ObservedObject var store: ResourceCodeStore
    
    var body: some View {
        if resourceType == "api" {
            contentAPIs
        } else if resourceType == "component" {
            contentComponents
        } else if resourceType == "template" {
            contentTemplates
        } else {
            Text("Unknown resource type -o-")
        }
    }
    
    var contentAPIs: some View {
        List {
            ForEach(store.apiModels) { item in
                ResourceCodeNavigationLink(item: item)
            }
        }
    }
    
    var contentComponents: some View {
        List {
            ForEach(store.componentModels) { item in
                ResourceCodeNavigationLink(item: item)
            }
        }
    }
    
    var contentTemplates: some View {
        List {
            ForEach(store.templateModels) { item in
                ResourceCodeNavigationLink(item: item)
            }
        }
    }
}

struct ResourceCodeView: View {
    let resourceType: String
    @StateObject var store = ResourceCodeStore()
    
    var body: some View {
        NavigationView {
            ResourceCodeListView(resourceType: resourceType,store: store)
            
            Text("Resources \(resourceType) :)")
        }
    }
}

struct ResourceCodeView_Previews: PreviewProvider {
    static var previews: some View {
        ResourceCodeView(resourceType: "api")
    }
}
