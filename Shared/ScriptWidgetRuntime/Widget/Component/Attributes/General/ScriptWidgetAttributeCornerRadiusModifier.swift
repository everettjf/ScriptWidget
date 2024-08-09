//
//  ScriptWidgetAttributeCornerRadiusModifier.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/3/1.
//

import SwiftUI

struct ScriptWidgetAttributeCornerRadiusModifier: ViewModifier {
    
    let cornerRadius: Double?
    
    init(_ element: ScriptWidgetRuntimeElement) {
        var cornerRadius: Double? = nil
        if let value = element.getPropDouble("corner") {
            cornerRadius = value
        }
        self.cornerRadius = cornerRadius
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let cornerRadius = self.cornerRadius {
            content
                .cornerRadius(cornerRadius)
        } else {
            content
        }
    }
}
