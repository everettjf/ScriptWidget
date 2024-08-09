//
//  ScriptWidgetAttributeOpacityModifier.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/27.
//

import SwiftUI


struct ScriptWidgetAttributeOpacityModifier: ViewModifier {
    
    let opacity: Double?
    
    init(_ element: ScriptWidgetRuntimeElement) {
        
        var opacity: Double? = nil
        if let value = element.getPropDouble("opacity") {
            opacity = value
        }
        self.opacity = opacity
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let opacity = self.opacity {
            content
                .opacity(opacity)
        } else {
            content
        }
    }
    
}
