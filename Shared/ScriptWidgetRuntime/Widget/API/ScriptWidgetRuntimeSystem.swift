//
//  ScriptWidgetRuntimeSystem.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import JavaScriptCore

#if os(iOS)
import UIKit
#endif

@objc protocol ScriptWidgetRuntimeSystemExports: JSExport {
    static func appInfo() -> [AnyHashable: Any]!
    static func locale() -> String
    static func preferredLanguages() -> [String]
    static func timeZone() -> [AnyHashable: Any]!
    static func is24HourClock() -> Bool
    static func calendarInfo() -> [AnyHashable: Any]!
    static func systemUptime() -> Double
    static func memory() -> [AnyHashable: Any]!
    static func thermalState() -> String
    static func lowPowerMode() -> Bool
    static func brightness() -> Double
    static func reduceMotionEnabled() -> Bool
    static func platform() -> String
    static func hostName() -> String
    static func processName() -> String
    static func osVersionString() -> String
    static func processorCount() -> Int
    static func activeProcessorCount() -> Int
}

@objc public class ScriptWidgetRuntimeSystem: NSObject, ScriptWidgetRuntimeSystemExports {
    static func appInfo() -> [AnyHashable: Any]! {
        let bundle = Bundle.main
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return [
            "name": displayName ?? bundleName ?? "",
            "bundleId": bundle.bundleIdentifier ?? "",
            "version": version,
            "build": build
        ]
    }

    static func locale() -> String {
        return Locale.current.identifier
    }

    static func preferredLanguages() -> [String] {
        return Locale.preferredLanguages
    }

    static func timeZone() -> [AnyHashable: Any]! {
        let tz = TimeZone.current
        return [
            "identifier": tz.identifier,
            "abbreviation": tz.abbreviation() ?? "",
            "offsetSeconds": tz.secondsFromGMT()
        ]
    }

    static func is24HourClock() -> Bool {
        let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current) ?? ""
        return !format.contains("a")
    }

    static func calendarInfo() -> [AnyHashable: Any]! {
        let calendar = Calendar.current
        return [
            "identifier": String(describing: calendar.identifier),
            "firstWeekday": calendar.firstWeekday,
            "minimumDaysInFirstWeek": calendar.minimumDaysInFirstWeek
        ]
    }

    static func systemUptime() -> Double {
        return ProcessInfo.processInfo.systemUptime
    }

    static func memory() -> [AnyHashable: Any]! {
        return [
            "physical": Int64(ProcessInfo.processInfo.physicalMemory)
        ]
    }

    static func thermalState() -> String {
        if #available(iOS 11.0, macOS 10.10, *) {
            switch ProcessInfo.processInfo.thermalState {
            case .nominal:
                return "nominal"
            case .fair:
                return "fair"
            case .serious:
                return "serious"
            case .critical:
                return "critical"
            @unknown default:
                return "unknown"
            }
        }
        return "unknown"
    }

    static func lowPowerMode() -> Bool {
        if #available(iOS 9.0, macOS 12.0, *) {
            return ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        return false
    }

    static func brightness() -> Double {
#if os(iOS)
        return Double(UIScreen.main.brightness)
#else
        return -1
#endif
    }

    static func reduceMotionEnabled() -> Bool {
#if os(iOS)
        return UIAccessibility.isReduceMotionEnabled
#else
        return false
#endif
    }

    static func platform() -> String {
#if os(macOS)
        return "macos"
#else
        return "ios"
#endif
    }

    static func hostName() -> String {
#if os(macOS)
        return Host.current().localizedName ?? ""
#else
        return UIDevice.current.name
#endif
    }

    static func processName() -> String {
        return ProcessInfo.processInfo.processName
    }

    static func osVersionString() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    static func processorCount() -> Int {
        return ProcessInfo.processInfo.processorCount
    }

    static func activeProcessorCount() -> Int {
        return ProcessInfo.processInfo.activeProcessorCount
    }
}
