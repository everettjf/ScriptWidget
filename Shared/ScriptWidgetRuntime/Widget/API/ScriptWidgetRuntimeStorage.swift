//
//  ScriptWidgetRuntimeStorage.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeStorageExports: JSExport {
    static func getString(_ key: String) -> String
    static func setString(_ key: String, _ value: String) -> Bool
    static func getJSON(_ key: String) -> [AnyHashable: Any]!
    static func setJSON(_ key: String, _ value: [AnyHashable: Any]) -> Bool
    static func remove(_ key: String) -> Bool
    static func keys() -> [String]
    static func clear() -> Bool
}

@objc public class ScriptWidgetRuntimeStorage: NSObject, ScriptWidgetRuntimeStorageExports {
    private static func defaults() -> UserDefaults {
        return UserDefaults(suiteName: "group.everettjf.scriptwidget") ?? UserDefaults.standard
    }

    static func getString(_ key: String) -> String {
        return defaults().string(forKey: key) ?? ""
    }

    static func setString(_ key: String, _ value: String) -> Bool {
        defaults().set(value, forKey: key)
        return true
    }

    static func getJSON(_ key: String) -> [AnyHashable: Any]! {
        guard let data = defaults().data(forKey: key) else {
            return [:]
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [AnyHashable: Any]
            return json ?? [:]
        } catch {
            print("storage getJSON error: \(error)")
            return [:]
        }
    }

    static func setJSON(_ key: String, _ value: [AnyHashable: Any]) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: [])
            defaults().set(data, forKey: key)
            return true
        } catch {
            print("storage setJSON error: \(error)")
            return false
        }
    }

    static func remove(_ key: String) -> Bool {
        defaults().removeObject(forKey: key)
        return true
    }

    static func keys() -> [String] {
        return Array(defaults().dictionaryRepresentation().keys)
    }

    static func clear() -> Bool {
        let allKeys = defaults().dictionaryRepresentation().keys
        for key in allKeys {
            defaults().removeObject(forKey: key)
        }
        return true
    }
}
