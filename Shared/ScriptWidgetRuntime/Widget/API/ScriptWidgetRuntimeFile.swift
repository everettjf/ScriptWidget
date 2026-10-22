//
//  ScriptWidgetRuntimeFile.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/4/1.
//

import Foundation
import Darwin
import JavaScriptCore


@objc protocol ScriptWidgetRuntimeFileExports: JSExport {
    static func exists(_ relativePath: String) -> Bool
    static func read(_ relativePath: String) -> String
    static func readJSON(_ relativePath: String) -> [AnyHashable: Any]!
}

@objc public class ScriptWidgetRuntimeFile: NSObject, ScriptWidgetRuntimeFileExports {
    private static func state() -> ScriptWidgetRunningState? {
        guard let state = JSContext.current()?.scriptWidgetRunningState else { return nil }
        do { try state.validateExecutionSnapshot(); return state }
        catch {
            JSContext.current()?.exception = JSValue(newErrorFromMessage: "[package:identity_changed] Reload the widget before reading package files.", in: JSContext.current())
            return nil
        }
    }

    /// Locally present regular package files only; never follows a link or downloads iCloud content.
    static func exists(_ relativePath: String) -> Bool {
        guard let package=state()?.package,package.resolvedPackageURL(relativePath:relativePath) != nil else { return false }
        return ScriptWidgetPackageFiles.kind(root:package.path,relative:relativePath)==S_IFREG
    }

    static func read(_ relativePath: String) -> String {
        guard let runningState = state() else {
            return ""
        }
        guard let content = runningState.package.readFile(relativePath: relativePath).0 else {
            return ""
        }
        return content
    }

    static func readJSON(_ relativePath: String) -> [AnyHashable: Any]! {
        guard let runningState = state() else {
            return [:]
        }
        guard let content = runningState.package.readFile(relativePath: relativePath).0 else {
            return [:]
        }
        
        guard let data = content.data(using: .utf8) else {
            return [:]
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [AnyHashable:Any]
            return json
        } catch { return [:] }
    }
    
}
