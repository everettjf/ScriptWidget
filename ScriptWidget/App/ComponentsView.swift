//
//  ApiListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI

struct ComponentsView: View {
    
    
    var body: some View {
        BundleScriptListView(navigationTitle: "Components", dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "component"))
    }
}

struct ComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentsView()
    }
}
