//
//  ScriptWidgetAttributeTextAlignmentModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/3/14.
//

import SwiftUI



struct ScriptWidgetAttributeTextAlignmentModifier: ViewModifier {
    
    let textAlignment: TextAlignment?
    
    init(_ element: ScriptWidgetRuntimeElement) {
        
        var textAlignment: TextAlignment? = nil
        if let alignmentValue = element.getPropString("alignment") {
            textAlignment = ScriptWidgetAttributeTextAlignmentModifier.getTextAlignmentStringName(alignmentValue)
        }
        self.textAlignment = textAlignment
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let textAlignment = self.textAlignment {
            content
                .multilineTextAlignment(textAlignment)
        } else {
            content
        }
    }
    
    static func getTextAlignmentStringName(_ name: String) -> TextAlignment? {
        var textAlignment: TextAlignment? = nil
        switch name {
        case "leading": textAlignment = .leading
        case "center" : textAlignment = .center
        case "trailing": textAlignment = .trailing
        default: textAlignment = nil
        }
        
        return textAlignment
    }
}
