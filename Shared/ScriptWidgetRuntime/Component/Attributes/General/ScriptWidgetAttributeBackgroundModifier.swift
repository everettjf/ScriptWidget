//
//  ScriptWidgetAttributeBackgroundModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI


struct ScriptWidgetAttributeBackgroundModifier: ViewModifier {
    
    let color: ScriptWidgetAttributeColor
    
    init(_ element: ScriptWidgetRuntimeElement) {
        if let backgroundValue = element.getPropString("background")  {
            color = ScriptWidgetAttributeColor(backgroundValue)
        } else {
            color = ScriptWidgetAttributeColor()
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let backgroundColor = self.color.color {
            content.background(backgroundColor)
        } else if let gradient = self.color.gradient {
            content.background(gradient)
        } else {
            content
        }
    }
    
}
