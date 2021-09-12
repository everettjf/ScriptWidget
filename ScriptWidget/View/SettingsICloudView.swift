//
//  SettingsICloudView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/27.
//

import SwiftUI

struct SettingsICloudView: View {
    
    func getText() -> String {
        let icloudEnable = sharedScriptManager.isICloudAvaliable()
        if !icloudEnable {
            return "iCloud is not enabled. So scripts will store to app's private sandbox and can not eazy export. It is recommended to enable iCloud, since you could directly open or edit scripts in system Files app."
        }
        
        let sandboxCount = ScriptManager.getSandboxFileCount()
        if sandboxCount > 0 {
            return "iCloud is enabled. But there are files in app's private sandbox that are not synced to iCloud. This problem exists when you not enable iCloud sometimes previously. But do not worry, just tap the MOVE button to move all sandbox files to iCloud. Then you could directly open or edit scripts in system Files app."
        }

        return "iCloud is enabled, you could directly open or edit scripts in system Files app."
    }
    
    var body: some View {
        HStack {
            Text(self.getText())
                .padding(.vertical, 8)
                .layoutPriority(1)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            
            if sharedScriptManager.isICloudAvaliable() && ScriptManager.getSandboxFileCount() > 0 {
                CountDownButton(text: "Move".uppercased(), waitSeconds: 2) {
                    if ScriptManager.moveSandboxFilesToICloud() {
                        
                    } else {
                        
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
