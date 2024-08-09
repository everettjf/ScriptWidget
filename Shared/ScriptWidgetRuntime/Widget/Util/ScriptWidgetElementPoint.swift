//
//  ScriptWidgetElementPoint.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/3/15.
//

import Foundation
import SwiftUI


class ScriptWidgetElementPoint {
    static func getPointFromPointValue(_ pointValue: String) -> UnitPoint {
        let parts = pointValue.split(separator: ",")
        if parts.count == 1 {
            var point: UnitPoint
            switch pointValue {
            case "zero": point = .zero
            case "center": point = .center
            case "leading": point = .leading
            case "trailing": point = .trailing
            case "top": point = .top
            case "bottom": point = .bottom
            case "topLeading": point = .topLeading
            case "topTrailing": point = .topTrailing
            case "bottomLeading": point = .bottomLeading
            case "bottomTrailing": point = .bottomTrailing
            default: point = .zero
            }
            
            return point
        } else if parts.count == 2 {
            // 100,50
            let x = Double(parts[0]) ?? 0
            let y = Double(parts[1]) ?? 0
            
            return UnitPoint(x: CGFloat(x), y: CGFloat(y))
        } else {
            return .zero
        }
    }
    
}
