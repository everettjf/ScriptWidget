//
//  ScriptWidgetGlobalState.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation
import UIKit

class ScriptWidgetGlobalState {
    let screenBounds = UIScreen.main.bounds
    let screenScale = UIScreen.main.scale
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }
}

let globalState = ScriptWidgetGlobalState()
