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
            return Text(LocalizedStringKey("icloud_not_enable_tip"))
        }
        
        let sandboxCount = ScriptManager.getSandboxFileCount()
        if sandboxCount > 0 {
            return Text(LocalizedStringKey("icloud_enable_transfer_tip"))
        }
        
        return Text(LocalizedStringKey("icloud_enable_tip"))
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
