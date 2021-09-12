//
//  ScriptWidgetElementTagVStack.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI

class ScriptWidgetElementTagVStack {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        return AnyView(ScriptWidgetElementTagVStack.buildVStack(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder static func buildVStack(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        VStack (alignment: ScriptWidgetElementTagVStack.getHorizontalAlignment(element) , spacing: ScriptWidgetElementTagVStack.getSpacing(element)) {
            ForEach(element.children as! [ScriptWidgetRuntimeElement]) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    static func getHorizontalAlignment(_ element: ScriptWidgetRuntimeElement) -> HorizontalAlignment {
        guard let alignment = element.getPropString("alignment") else { return .center }
        
        switch alignment {
        case "leading": return .leading
        case "trailing": return .trailing
        case "center": return .center
        default: return .center
        }
    }
    
    static func getSpacing(_ element: ScriptWidgetRuntimeElement) -> CGFloat? {
        guard let spacing = element.getPropDouble("spacing") else { return nil }
        return CGFloat(spacing)
    }
}
