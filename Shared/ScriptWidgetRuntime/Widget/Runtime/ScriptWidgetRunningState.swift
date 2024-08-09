//
//  ScriptWidgetRunningState.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/4/7.
//

import Foundation


class ScriptWidgetConsoleLogger {
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


class ScriptWidgetRunningState {
    
    var logger: ScriptWidgetConsoleLogger
    var package: ScriptWidgetPackage
    
    init(package: ScriptWidgetPackage) {
        self.logger = ScriptWidgetConsoleLogger()
        self.package = package
    }
}

var sharedRunningState: ScriptWidgetRunningState? = nil

