//
//  SwiftWidgetRuntimeConsole.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/15.
//

import Foundation
import JavaScriptCore


class ScriptWidgetConsoleLogManager {
    var logs: [String] = []
    
    func addLog(_ log: String) {
        DispatchQueue.main.async {
            self.logs.append(log)
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}

let sharedConsoleLogManager = ScriptWidgetConsoleLogManager()

@objc protocol ScriptWidgetRuntimeConsoleExports: JSExport {
    static func log(_ string: String) -> Void
    static func error(_ string: String) -> Void
}

@objc public class ScriptWidgetRuntimeConsole: NSObject, ScriptWidgetRuntimeConsoleExports {
    class func log(_ string: String) {
        sharedConsoleLogManager.addLog(string)
        print("console log : \(string)")
    }
    class func error(_ string: String) {
        sharedConsoleLogManager.addLog(string)
        print("console error : \(string)")
    }
}
