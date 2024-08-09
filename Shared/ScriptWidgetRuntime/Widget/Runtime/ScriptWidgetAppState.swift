//
//  ScriptWidgetGlobalState.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

class ScriptWidgetAppState {
    
#if os(macOS)
    let screenBounds = NSScreen.main!.frame
    let screenScale = 0.5
#else
    let screenBounds = UIScreen.main.bounds
    let screenScale = UIScreen.main.scale
#endif
    
    
    init() {
        #if os(macOS)
        #else
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
    }
}

let sharedAppState = ScriptWidgetAppState()
