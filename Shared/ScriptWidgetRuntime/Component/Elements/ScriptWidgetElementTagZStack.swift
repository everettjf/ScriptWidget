//
//  ScriptWidgetElementTagZStack.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI

class ScriptWidgetElementTagZStack {
    
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(ScriptWidgetElementTagZStack.buildZStack(element: element, context: context))
    }
    
    @ViewBuilder static func buildZStack(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        ZStack {
            ForEach(element.children as! [ScriptWidgetRuntimeElement]) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
}
