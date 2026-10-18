//
//  ScriptWidgetElementTagDate.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation
import SwiftUI

/// The clock `<date>` uses for absolute styles (`time`, `date`). Tests that
/// compare snapshots set `fixedNow`; the app always leaves it nil. Relative
/// styles keep the real clock because SwiftUI measures them against it.
enum ScriptWidgetRenderClock {
    nonisolated(unsafe) static var fixedNow: Date?
}

class ScriptWidgetElementTagDate {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        var dateStyle: Text.DateStyle = .timer
        if let style = element.getPropString("style") {
            dateStyle = ScriptWidgetElementTagDate.getStyle(styleName: style)
        }
        
        let absolute = dateStyle == .time || dateStyle == .date
        let now = (absolute ? ScriptWidgetRenderClock.fixedNow : nil) ?? Date()
        var date: Date = now
        if let dateName = element.getPropString("date") {
            date = ScriptWidgetElementTagDate.getDate(dateName: dateName, now: now)
        } else if let dateTimestamp = element.getPropDouble("date") {
            date = Date(timeIntervalSince1970: dateTimestamp / 1000.0)
        }
        
        return AnyView(
            Text(date ,style: dateStyle)
                .modifier(ScriptWidgetAttributeTextModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
    
    static func getDate(dateName: String, now: Date = Date()) -> Date {
        if (dateName == "now") {
            return now
        } else if (dateName == "tomorrow") {
            return now.advanced(by: 1*24*60*60)
        } else if (dateName == "yesterday") {
            return now.advanced(by: -1*24*60*60)
        } else if (dateName == "start of today") {
            return Calendar.current.startOfDay(for: now)
        } else if (dateName.hasPrefix("+") || dateName.hasPrefix("-")) {
            var advancedValue:TimeInterval = 60*60;
            if (dateName.hasPrefix("+")) {
                advancedValue *= 1
            } else {
                advancedValue *= -1
            }
            if (dateName.hasSuffix("h")) {
                advancedValue *= 1
            } else if (dateName.hasSuffix("d")) {
                advancedValue *= 24
            }
            
            var middleValue: Int = 0
            if (dateName.count >= 3) {
                var middleString = dateName
                middleString = String(middleString.dropFirst())
                middleString = String(middleString.dropLast())
                middleValue = Int(middleString) ?? 0
            }
            
            return now.advanced(by: advancedValue * Double(middleValue))
        }
        return now
    }
    
    static func getStyle(styleName: String) -> Text.DateStyle {
        switch styleName {
        case "time": return .time
        case "date": return .date
        case "relative": return .relative
        case "offset": return .offset
        case "timer": return .timer
        default: return .time
        }
    }
}
