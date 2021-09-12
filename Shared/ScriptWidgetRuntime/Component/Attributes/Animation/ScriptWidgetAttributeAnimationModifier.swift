//
//  ScriptWidgetAttributeAnimationModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/3/15.
//

import SwiftUI
#if IsWidgetTarget
import SwiftyJSON

/*
 
 animation:<json>
 
 let animationSecond = {
 type: "clockSecond",  // clockMinute , clockHour
 timezone: "current",
 anchor: "center"
 }
 
 
 let animationCustom = {
 type: "clockCustom",
 interval: 10, // 10 seconds
 timezone: "current",
 anchor: "center"
 }
 
 
 */

struct ScriptWidgetAttributeAnimationModifier: ViewModifier {
    
    let animationType: String
    
    let clockTimezone: TimeZone
    let clockAnchor: UnitPoint
    let clockCustomInterval: TimeInterval
    
    init(_ element: ScriptWidgetRuntimeElement) {
        
        var animationType = ""
        var clockTimezone: TimeZone = .current
        var clockAnchor: UnitPoint = .center
        var clockCustomInterval: TimeInterval = 10
        if let animationTypeValue = element.getPropString("animation") {
            
            if animationTypeValue.starts(with: "animation:") {
                // json support
                let jsonString = animationTypeValue.dropFirst("animation:".count)
                if let jsonData = jsonString.data(using: .utf8)  {
                    do {
                        let json = try JSON(data: jsonData)
                        
                        let type = json["type"].stringValue
                        animationType = type
                        
                        if let timezoneValue = json["timezone"].string {
                            clockTimezone = ScriptWidgetAttributeAnimationModifier.getTimezone(timezone: timezoneValue)
                        }
                        
                        if let anchorValue = json["anchor"].string {
                            clockAnchor = ScriptWidgetElementPoint.getPointFromPointValue(anchorValue)
                        }
                        
                        if let intervalValue = json["interval"].double {
                            clockCustomInterval = TimeInterval(intervalValue)
                            if clockCustomInterval < 1 {
                                clockCustomInterval = 1
                            }
                        }
                        
                    } catch {
                        print("animation json parse error : \(error)")
                    }
                }
            } else {
                // quick format
                let parts = animationTypeValue.split(separator: ",")
                if parts.count == 1 {
                    // clockSecond
                    // clockMiniute
                    // clockHour
                    animationType = animationTypeValue
                } else if parts.count == 2 {
                    // clockCustom,10
                    animationType = String(parts[0])
                    if let intervalValue = Double(String(parts[1])) {
                        clockCustomInterval = intervalValue
                    }
                }
            }
        }
        
        self.animationType = animationType
        self.clockTimezone = clockTimezone
        self.clockAnchor = clockAnchor
        self.clockCustomInterval = clockCustomInterval
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if animationType == "clockSecond" {
            content
                ._clockHandRotationEffect(.secondHand, in: self.clockTimezone, anchor: self.clockAnchor)
        } else if animationType == "clockMiniute" {
            content
                ._clockHandRotationEffect(.minuteHand, in: self.clockTimezone, anchor: self.clockAnchor)
        } else if animationType == "clockHour" {
            content
                ._clockHandRotationEffect(.hourHand, in: self.clockTimezone, anchor: self.clockAnchor)
        } else if animationType == "clockCustom" {
            content
                ._clockHandRotationEffect(.custom(self.clockCustomInterval), in: self.clockTimezone, anchor: self.clockAnchor)
        } else {
            content
        }
    }
    
    
    static func getTimezone(timezone: String) -> TimeZone {
        if timezone == "current" {
            return .current
        }
        
        if let timezone = TimeZone(identifier: timezone) {
            return timezone
        }
        
        // default
        return .current
    }
}

#else

struct ScriptWidgetAttributeAnimationModifier: ViewModifier {
    
    init(_ element: ScriptWidgetRuntimeElement) {
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        content
    }
}

#endif
