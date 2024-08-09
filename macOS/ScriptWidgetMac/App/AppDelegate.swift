//
//  AppDelegate.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/14.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("did finish launching")
        
        runEditorWebService()
    }
    
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
