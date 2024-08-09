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
    let package: ScriptWidgetPackage
    
    var rootElement : ScriptWidgetDynamicIslandRuntimeElement
    var runtime: ScriptWidgetRuntime?
    
    init(scriptName: String, scriptParameter: String) {
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        
        self.package = buildScriptManager.getScriptPackage(packageName: self.scriptName)
        
        self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: ".")
    }
    
    func runScriptSync() {
        if self.scriptName.count == 0 {
            self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: "No script selected")
            return
        }
        
        self.systemLog("[START]")
        
        let (JSX, errorInfo) = self.package.readMainFile()
        guard let JSX = JSX else {
            self.rootElement = ScriptWidgetDynamicIslandRuntimeElement(text: "Failed to open script : \(errorInfo)")
            return
        }
        
        let runtime = ScriptWidgetRuntime(package: self.package, environments: [
            "widget-size" : "dynamic-island",
            "widget-param": scriptParameter,
        ])
        
        let result = runtime.executeJSXSyncForDynamicIsland(JSX)
        
        if let element = result.0 {
            // succeed
            self.rootElement = element
            self.runtime = runtime
        } else {
            // error
            self.runtime = nil
            
            if let error = result.1 {
                switch error {
                case .undefinedRender(let msg):
                    self.systemLog(msg)
                case .internalError(let msg):
                    self.systemLog(msg)
                case .scriptError(let msg):
                    self.systemLog(msg)
                case .scriptException(let msg):
                    self.systemLog(msg)
                case .transformError(let msg):
                    self.systemLog(msg)
                }
            }
        }
        
        self.systemLog("[FINISH]")
    }
    
    func systemLog(_ str: String) {
        print("system log: \(str)")
    }
}
