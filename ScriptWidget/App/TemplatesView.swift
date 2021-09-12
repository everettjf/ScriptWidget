//
//  TemplatesView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/8.
//

import SwiftUI

struct TemplatesView: View {
    var body: some View {
        BundleScriptListView(navigationTitle: "Templates", dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "template"))
    }
}

struct TemplatesView_Previews: PreviewProvider {
    static var previews: some View {
        TemplatesView()
    }
}
