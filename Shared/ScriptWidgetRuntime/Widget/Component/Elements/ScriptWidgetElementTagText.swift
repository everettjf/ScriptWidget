//
//  ScriptWidgetElementText.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation
import SwiftUI


/*
 
 
 
 attributes:
 - font
 - gradientForeground
 
 
 */

class ScriptWidgetElementTagText {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        // get text
        var text = ""
        if let children = element.children {
            for child in children {
                if let value = child as? String {
                    text.append(value)
                } else if let value = child as? NSNumber {
                    text.append("\(value)")
                } else {
                    text.append("#ErrorChildType#")
                }
            }
        }
        
        return AnyView(
            Text(text)
                .modifier(ScriptWidgetAttributeTextModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}
