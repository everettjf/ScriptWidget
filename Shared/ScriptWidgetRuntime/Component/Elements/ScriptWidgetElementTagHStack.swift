//
//  ScriptWidgetElementTagHStack.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI

class ScriptWidgetElementTagHStack {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(ScriptWidgetElementTagHStack.buildHStack(element: element, context: context))
    }
    
    @ViewBuilder static func buildHStack(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        HStack (alignment: ScriptWidgetElementTagHStack.getVerticalAlignment(element), spacing: ScriptWidgetElementTagHStack.getSpacing(element)) {
            ForEach(element.children as! [ScriptWidgetRuntimeElement]) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    static func getVerticalAlignment(_ element: ScriptWidgetRuntimeElement) -> VerticalAlignment {
        guard let alignment = element.getPropString("alignment") else { return .center }
        
        switch alignment {
        case "top": return .top
        case "bottom": return .bottom
        case "center": return .center
        case "firstTextBaseline": return .firstTextBaseline
        case "lastTextBaseline": return .lastTextBaseline
        default: return .center
        }
    }
    
    static func getSpacing(_ element: ScriptWidgetRuntimeElement) -> CGFloat? {
        guard let spacing = element.getPropDouble("spacing") else { return nil }
        return CGFloat(spacing)
    }
}
