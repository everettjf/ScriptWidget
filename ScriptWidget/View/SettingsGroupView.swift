//
//  SettingsGroupView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/3/2.
//

import SwiftUI

struct SettingsGroupView: View {
    var body: some View {
        VStack {
            
            if Locale.preferredLanguages[0] == "zh-Hans-CN" {
                SettingsLinkRowView(name: "Wechat", label: "Join", urlString: "https://scriptwidget.app/docs/group")
                
                SettingsLinkRowView(name: "Weibo", label: "Follow", urlString: "https://weibo.com/scriptwidget")
                
            } else {
                
                SettingsLinkRowView(name: "Telegram", label: "Join", urlString: "https://t.me/scriptwidgetapp")
                
                SettingsLinkRowView(name: "Twitter", label: "Follow", urlString: "https://twitter.com/ScriptWidget")
            }
            
            SettingsLinkRowView(name: "Mail", label: "Send", urlString: "mailto:everettjf@gmail.com?subject=ScriptWidget_Feedback")
            
        }
    }
}

struct SettingsGroupView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsGroupView()
    }
}
