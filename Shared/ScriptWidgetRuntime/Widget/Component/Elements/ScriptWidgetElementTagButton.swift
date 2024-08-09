//
//  ScriptWidgetElementTagButton.swift
//  ScriptWidget
//
//  Created by zhufeng on 2023/10/7.
//
import Foundation
import SwiftUI
import SwiftyJSON

class ScriptWidgetElementTagButton {
    
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(Self.buildButton(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder private static func buildButton(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        Button(intent: ButtonActionAppIntent(functionName: Self.getButtonActionFunctionName(element), package: context.package)) {
            ForEach(element.childrenAsElements()) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    static func getButtonActionFunctionName(_ element: ScriptWidgetRuntimeElement) -> String {
        guard let functionName = element.getPropString("onClick") else { return "" }
        return functionName
    }
    
}
