//
//  ScriptWidgetAttributeRotationEffectModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/18.
//

import SwiftUI

/*
 
 .rotationEffect(Angle(degrees: 90))

 */

struct ScriptWidgetAttributeRotationEffectModifier: ViewModifier {

    var degree: Double?

    init(_ element: ScriptWidgetRuntimeElement) {

        if let rotationValue = element.getPropDouble("rotation") {
            self.degree = rotationValue
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let degree = self.degree {
            content
                .rotationEffect(Angle(degrees: degree))
        } else {
            content
        }
    }
}
