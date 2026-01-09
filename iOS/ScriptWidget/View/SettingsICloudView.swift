//
//  SettingsICloudView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/27.
//

import SwiftUI

struct SettingsICloudView: View {
    
    func getText() -> Text {
        let icloudEnable = sharedScriptManager.isICloudAvaliable()
        if !icloudEnable {
            return Text("iCloud is not enabled. So scripts will store to app's private sandbox and can not eazy export. It is recommended to enable iCloud, since you could directly open or edit scripts in system Files app.")
        }
        
        let sandboxCount = ScriptManager.getSandboxFileCount()
        if sandboxCount > 0 {
            return Text("iCloud storage is enabled but there are some older files that still needs to be moved to iCloud. Press \"MOVE\" to move those files to iCloud. This problem exists when you not enable iCloud sometimes previously.")
        }
        
        return Text("iCloud is enabled, you could directly open or edit scripts in system Files app.")
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                self.getText()
                    .padding(.vertical, 8)
                    .layoutPriority(1)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                
                if sharedScriptManager.isICloudAvaliable() && ScriptManager.getSandboxFileCount() > 0 {
                    CountDownButton(text: "MOVE", waitSeconds: 2) {
                        if ScriptManager.moveSandboxFilesToICloud() {
                            
                        } else {
                            
                        }
                    }
                }
            }
            
            if sharedScriptManager.isICloudAvaliable() {
                HStack(spacing: 0) {
                    Text("If you modified scripts directly on iCloud on other devices, you could request iCloud to update all the scripts.")
                        .padding(.vertical, 8)
                        .layoutPriority(1)
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                    
                    CountDownButton(text: "UPDATE", waitSeconds: 10) {
                        sharedScriptManager.requestUpdateICloudScripts()
                    }
                }
            }
        }
    }
}

struct SettingsICloudView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsICloudView()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.light)
        
        SettingsICloudView()
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
        
    }
}
