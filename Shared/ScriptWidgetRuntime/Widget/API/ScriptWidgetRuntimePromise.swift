//
//  ScriptWidgetRuntimePromise.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/12/10.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimePromiseExports: JSExport {
    func then(_ resolve: JSValue, _ reject: JSValue) -> Void
}

class ScriptWidgetRuntimePromise: NSObject, ScriptWidgetRuntimePromiseExports {
    
    var callback: (JSValue,JSValue) -> Void
    
    init(callback: @escaping (JSValue,JSValue) -> Void) {
        self.callback = callback
    }
    
    func then(_ resolve: JSValue, _ reject: JSValue) -> Void {
        self.callback(resolve, reject)
    }
}
