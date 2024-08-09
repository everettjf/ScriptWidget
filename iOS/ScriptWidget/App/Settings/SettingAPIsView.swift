//
//  SettingsAPIsView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/9.
//

import SwiftUI

struct SettingAPIsView: View {
    var body: some View {
        BundleScriptListView(navigationTitle: "APIs",inlineTitle: true,dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "api"))
    }
}

struct SettingAPIsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingAPIsView()
    }
}
