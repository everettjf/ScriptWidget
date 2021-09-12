//
//  ApiListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/24.
//

import SwiftUI


struct APIsView: View {
    
    var body: some View {
        BundleScriptListView(navigationTitle: "APIs", dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "api"))
    }
}

struct ApiListView_Previews: PreviewProvider {
    static var previews: some View {
        APIsView()
    }
}
