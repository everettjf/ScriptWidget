//
//  ScriptWidgetElementTagToggle.swift
//  ScriptWidget
//
//  Created by zhufeng on 2023/10/8.
//

import Foundation
import SwiftUI
import SwiftyJSON

class ScriptWidgetElementTagToggle {
    
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(Self.buildToggle(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder private static func buildToggle(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        Toggle(isOn: self.getToggleValue(element), intent: ButtonActionAppIntent(functionName: Self.getToggleActionFunctionName(element), package: context.package)) {
            ForEach(element.childrenAsElements()) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    static func getToggleActionFunctionName(_ element: ScriptWidgetRuntimeElement) -> String {
        guard let functionName = element.getPropString("onClick") else { return "" }
        return functionName
    }
    
    static func getToggleValue(_ element: ScriptWidgetRuntimeElement) -> Bool {
        return element.getPropBool("on") ?? false
    }
    
}
