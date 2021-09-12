//
//  ScriptWidgetAttributeShadowModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/18.
//

import Foundation
import SwiftUI

/*
 
 .shadow(color: Color(#colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)).opacity(0.3), radius: 3, x: 0, y: 3)

 */
struct ScriptWidgetAttributeShadowModifier: ViewModifier {
    
    
    var color: Color?
    var radius: CGFloat = 3
    var x: CGFloat = 0
    var y: CGFloat = 3

    init(_ element: ScriptWidgetRuntimeElement) {

        if let shadowValue = element.getPropString("shadow") {
            let parts = shadowValue.components(separatedBy: ",")
            if parts.count == 1 {
                if let color = ScriptWidgetAttributeColor(shadowValue).color {
                    self.color = color
                }
            } else if parts.count == 4 {
                if let color = ScriptWidgetAttributeColor(parts[0]).color {
                    self.color = color
                }
                if let radiusValue = Double(parts[1]) { self.radius = CGFloat(radiusValue) }
                if let xValue = Double(parts[2]) { self.x = CGFloat(xValue) }
                if let yValue = Double(parts[3]) { self.y = CGFloat(yValue) }
            }
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let color = self.color {
            content
                .shadow(color: color, radius: self.radius, x: self.x, y: self.y)
        } else {
            content
        }
    }
    
}
