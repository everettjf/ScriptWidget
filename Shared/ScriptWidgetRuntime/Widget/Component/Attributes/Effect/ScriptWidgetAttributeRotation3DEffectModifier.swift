//
//  ScriptWidgetAttributeRotation3DEffectModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/18.
//

import SwiftUI


/*
 
 .rotation3DEffect(Angle(degrees: 180), axis: (x: 1, y: 0, z: 0))

 */

struct ScriptWidgetAttributeRotation3DEffectModifier: ViewModifier {

    var degree: Double?
    var x: CGFloat = 1
    var y: CGFloat = 0
    var z: CGFloat = 0

    init(_ element: ScriptWidgetRuntimeElement) {

        if let rotation3dValue = element.getPropString("rotation3d") {
            let parts = rotation3dValue.components(separatedBy: ",")
            if parts.count == 4 {
                if let degreeValue = Double(parts[0]) { self.degree = degreeValue }
                if let xValue = Double(parts[1]) { self.x = CGFloat(xValue) }
                if let yValue = Double(parts[2]) { self.y = CGFloat(yValue) }
                if let zValue = Double(parts[3]) { self.z = CGFloat(zValue) }
            }
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let degree = self.degree {
            content
                .rotation3DEffect(Angle(degrees: degree), axis: (x: self.x, y: self.y, z: self.z))
        } else {
            content
        }
    }
}
