//
//  ScriptWidgetApp.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/4.
//

import SwiftUI
import WidgetKit

@main
struct ScriptWidgetApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate;
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: { url in
                    print("onOpenURL \(url)")
                    
                    guard let host = url.host() else {
                        return
                    }
                    
                    if let scheme = url.scheme {
                        if scheme == "scriptwidget" {
                            dealWithSelfScheme(host: host, url: url)
                            return
                        }
                    }
                    
                    if host == "scriptwidget.app" {
                        print("ignore open url for : scriptwidget.app")
                        UIApplication.shared.open(url)
                        return
                    }
                    
                    DeepLinkManager.openDeepLink(url: url)
                })
        }
    }
    
    
    func dealWithSelfScheme(host: String, url: URL) {
        if host == "reload-all" {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
