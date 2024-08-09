//
//  ScriptWidgetAttributeText.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI

struct ScriptWidgetAttributeTextModifier: ViewModifier {
    
    let element: ScriptWidgetRuntimeElement
    
    init(_ element: ScriptWidgetRuntimeElement) {
        self.element = element
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(ScriptWidgetAttributeTextAlignmentModifier(element))
            .modifier(ScriptWidgetAttributeFontModifier(element))
            .modifier(ScriptWidgetAttributeForegroundModifier(element))
    }
    
}
