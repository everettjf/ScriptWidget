//
//  DeepLinkManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/12.
//

import Foundation


class DeepLinkManager {
    
    static func openDeepLink(url: URL) {
        if url.scheme == kDeepLinkDefaultScheme {
            print("no need open url")
            return
        }
        
        print("try open url \(url)")
        if UIApplication.shared.canOpenURL(url) {
            print("can open url : \(url)")
        } else {
            print("can not open url : \(url)")
        }
        
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                print("succeed open url \(url)")
            } else {
                print("failed open url \(url)")
            }
        }
    }
}
