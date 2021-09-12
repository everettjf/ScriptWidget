//
//  ScriptWidgetApp.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/4.
//

import SwiftUI

@main
struct ScriptWidgetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate;
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: { url in
                    print("onOpenURL \(url)")
                    
                    DeepLinkManager.openDeepLink(url: url)
                })
        }
    }
}
