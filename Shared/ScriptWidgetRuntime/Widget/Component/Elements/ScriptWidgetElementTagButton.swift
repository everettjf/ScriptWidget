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

    private enum ButtonAction {
        case reload
        case callFunction(String)
    }
    
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(Self.buildButton(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder private static func buildButton(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        let action = getButtonAction(element)
        switch action {
        case .reload:
            Button(intent: ReloadWidgetAppIntent()) {
                ForEach(element.childrenAsElements()) { item -> AnyView in
                    return ScriptWidgetElementView.buildView(element: item, context: context)
                }
            }
            .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        case .callFunction(let functionName):
            Button(intent: ButtonActionAppIntent(functionName: functionName, package: context.package)) {
                ForEach(element.childrenAsElements()) { item -> AnyView in
                    return ScriptWidgetElementView.buildView(element: item, context: context)
                }
            }
            .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        }
    }
    
    private static func getButtonAction(_ element: ScriptWidgetRuntimeElement) -> ButtonAction {
        if let action = element.getPropString("action")?.lowercased(), action == "reload" {
            return .reload
        }
        let functionName = element.getPropString("onClick") ?? ""
        return .callFunction(functionName)
    }
    
}
