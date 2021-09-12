//
//  SwiftWidgetRuntimeDevice.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/15.
//

import Foundation
import JavaScriptCore
import UIKit

@objc protocol ScriptWidgetRuntimeDeviceExports: JSExport {
    static func screen() -> [AnyHashable: Any]!
    static func language() -> String
    static func model() -> String
    static func name() -> String
    static func battery() -> [AnyHashable: Any]!
    static func systemVersion() -> String
    static func isdarkmode() -> Bool
    static func totalDiskSpace() -> Int64
    static func freeDiskSpace() -> Int64
}

@objc public class ScriptWidgetRuntimeDevice: NSObject, ScriptWidgetRuntimeDeviceExports {
    
    static func totalDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let space = (systemAttributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
            return space ?? 0
        } catch {
            return 0
        }
    }
    
    static func freeDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory() as String)
            let freeSpace = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
            return freeSpace ?? 0
        } catch {
            return 0
        }
    }
    
    
    static func isdarkmode() -> Bool {
        return UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    static func screen() -> [AnyHashable : Any]! {
        let bounds = UIScreen.main.bounds
        return [
            "scale" : UIScreen.main.scale,
            "width" : bounds.width,
            "height": bounds.height,
        ]
    }
    
    static func language() -> String {
        return NSLocale.current.languageCode ?? ""
    }
    
    static func model() -> String {
        return UIDevice.current.model
    }
    
    static func name() -> String {
        return UIDevice.current.name
    }
    
    static func battery() -> [AnyHashable : Any]! {
        var level = UIDevice.current.batteryLevel
        if level < 0 {
            level = 0
        }
        
        var state = "unknown"
        switch UIDevice.current.batteryState {
        case .unknown: state = "unknown"
        case .charging: state = "charging"
        case .full: state = "full"
        case .unplugged: state = "unplugged"
        default: state = "default"
        }
        
        return [
            "level" : level,
            "state" : state
        ]
    }
    
    static func systemVersion() -> String {
        return UIDevice.current.systemVersion
    }
}
