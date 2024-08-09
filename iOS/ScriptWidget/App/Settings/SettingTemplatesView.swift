//
//  TemplatesView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/8.
//

import SwiftUI

struct SettingTemplatesView: View {
    var body: some View {
        BundleScriptListView(navigationTitle: "Templates", inlineTitle: true, dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "template"))
    }
}

struct SettingTemplatesView_Previews: PreviewProvider {
    static var previews: some View {
        SettingTemplatesView()
    }
}
