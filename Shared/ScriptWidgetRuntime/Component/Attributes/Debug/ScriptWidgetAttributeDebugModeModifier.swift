//
//  ScriptWidgetAttributeDebugModeModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI


struct ScriptWidgetAttributeDebugModeModifier: ViewModifier {
    
    let borderColor: Color
    let context: ScriptWidgetElementContext
    
    init(_ borderColor: Color, _ context: ScriptWidgetElementContext) {
        self.borderColor = borderColor
        self.context = context
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if context.debugMode {
            content
                .border(borderColor, width: 1)
        } else {
            content
        }
    }
    
}
