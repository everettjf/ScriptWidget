//
//  ScriptWidgetAttributeClippedModifier.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/3/1.
//

import SwiftUI

struct ScriptWidgetAttributeClippedModifier: ViewModifier {
    
    let clipped: Bool
    let shape: String
    
    init(_ element: ScriptWidgetRuntimeElement) {
        
        var clipped = false
        var shape = ""
        
        // clipped only
        if let value = element.getPropInt("clip") {
            // clipped
            clipped = (value == 1)
        }
        
        if let value = element.getPropString("clip") {
            clipped = true
            shape = value
        }
        
        self.clipped = clipped
        self.shape = shape
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if clipped {
            switch shape {
            case "circle" : content.clipShape(Circle())
            case "rect" : content.clipShape(Rectangle())
            case "capsule" : content.clipShape(Capsule())
            case "ellipse" : content.clipShape(Ellipse())
            default: content.clipped()
            }
        } else {
            content
        }
    }
    
}
