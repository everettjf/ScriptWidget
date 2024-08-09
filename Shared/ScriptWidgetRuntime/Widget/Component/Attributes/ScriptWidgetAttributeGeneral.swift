//
//  ScriptWidgetAttributeGeneral.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI

struct ScriptWidgetAttributeGeneralModifier: ViewModifier {
    
    let element: ScriptWidgetRuntimeElement
    let context: ScriptWidgetElementContext

    init(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) {
        self.element = element
        self.context = context
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(ScriptWidgetAttributeFrameModifier(element))
            .modifier(ScriptWidgetAttributeCornerRadiusModifier(element))
            .modifier(ScriptWidgetAttributeClippedModifier(element))
            .modifier(ScriptWidgetAttributeBackgroundModifier(element))
            .modifier(ScriptWidgetAttributePaddingModifier(element))
            .modifier(ScriptWidgetAttributeOpacityModifier(element))
            .modifier(ScriptWidgetAttributeAnimationModifier(element))
            .modifier(ScriptWidgetAttributeRotationEffectModifier(element))
            .modifier(ScriptWidgetAttributeRotation3DEffectModifier(element))
            .modifier(ScriptWidgetAttributeShadowModifier(element))
            .modifier(ScriptWidgetAttributeDebugModeModifier(Color.random, context))
    }
    
}
