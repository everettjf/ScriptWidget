//
//  SettingsComponentsView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/9.
//

import SwiftUI

struct SettingComponentsView: View {
    var body: some View {
        BundleScriptListView(navigationTitle: "Components", inlineTitle: true, dataObject: BundleScriptDataObject(bundleName: "Script", bundleDirectory: "component"))
    }
}

struct SettingComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingComponentsView()
    }
}
