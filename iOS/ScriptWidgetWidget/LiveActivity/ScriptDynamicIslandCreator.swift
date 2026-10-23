//
//  ScriptDynamicIslandDataObject.swift
//  ScriptWidgetWidget
//
//  Created by everettjf on 2022/9/25.
//

import Foundation
import SwiftUI
import WidgetKit

class ScriptDynamicIslandCreator {
    let scriptName: String
    let scriptParameter: String
    let scriptState: String
    let binding: ScriptWidgetLiveActivityBinding?
    let isStale: Bool
    private(set) var package: ScriptWidgetPackage = globalScriptWidgetPackage
    
    var rootElement : ScriptWidgetDynamicIslandRuntimeElement
    var runtime: ScriptWidgetRuntime?
    
    init(scriptName: String, scriptParameter: String, scriptState: String, binding: ScriptWidgetLiveActivityBinding? = nil, isStale: Bool = false) {
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        self.scriptState = scriptState
        self.binding=binding;self.isStale=isStale
        
        
        self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: ".")
    }
    
    func runScriptSync() {
        if self.scriptName.count == 0 {
            self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: "No script selected")
            return
        }
        
        self.systemLog("[START]")
        
        self.runtime = nil
        let execution: ScriptWidgetHostExecution
        do {
            guard let binding else { throw ScriptWidgetLiveActivityBindingError.invalidBinding }
            execution = try binding.load(cacheOnly:true)
            self.package = execution.package
        } catch {
            let message = (error as? ScriptWidgetLiveActivityBindingError)?.localizedDescription
                ?? (error as? ScriptWidgetHostReadError)?.message
                ?? "Widget library unavailable. Open ScriptWidget to check the selected library."
            self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: message)
            return
        }
        let JSX = execution.source

        let runtime = ScriptWidgetRuntime(package: self.package, environments: [
            "widget-size" : "dynamic-island",
            "widget-param": scriptParameter,
            "live-activity-state": scriptState,
            "live-activity-is-stale": isStale ? "true" : "false",
            "live-activity-surface": "dynamicIsland",
        ], executionSnapshot: execution.snapshot)
        
        let result = runtime.executeJSXSyncForDynamicIsland(JSX)
        
        if let element = result.0 {
            // succeed
            self.rootElement = element
            self.runtime = runtime
        } else {
            // error
            self.runtime = nil
            
            if let error = result.1 {
                let message = error.displayMessage
                self.systemLog("[runtime_error]")
                self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: message)
            }
        }

        self.systemLog("[FINISH]")
    }

    func systemLog(_ str: String) {
        SWLog.info(str)
    }
}
