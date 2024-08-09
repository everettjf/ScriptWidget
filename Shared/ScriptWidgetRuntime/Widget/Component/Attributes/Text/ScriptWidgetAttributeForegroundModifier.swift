//
//  ScriptWidgetAttributeForegroundModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI


extension View {
    
    public func gradientForeground<Overlay>(_ overlay: Overlay) -> some View where Overlay : View {
        self.overlay(overlay)
            .mask(self)
    }
    
    public func gradientForegroundColors(colors: [Color]) -> some View {
        self.overlay(LinearGradient(gradient: .init(colors: colors),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing))
            .mask(self)
    }
}


struct ScriptWidgetAttributeForegroundModifier: ViewModifier {
    
    let color: ScriptWidgetAttributeColor
    
    init(_ element: ScriptWidgetRuntimeElement, colorField: String) {
        if let foregroundValue = element.getPropString(colorField) {
            color = ScriptWidgetAttributeColor(foregroundValue)
        } else {
            color = ScriptWidgetAttributeColor()
        }
    }
    
    init(_ element: ScriptWidgetRuntimeElement) {
        self.init(element, colorField: "color")
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let foregroundColor = self.color.color {
            content.foregroundColor(foregroundColor)
        } else if let gradient = self.color.gradient {
            content.gradientForeground(gradient)
        } else {
            content
        }
    }
    
}

