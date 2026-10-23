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

struct ScriptWidgetRotation3D {
    let degree: Double
    let x: CGFloat
    let y: CGFloat
    let z: CGFloat

    init?(_ value: String) {
        let parts = value.components(separatedBy:",").compactMap { Double($0.trimmingCharacters(in:.whitespacesAndNewlines)) }
        guard parts.count == 4, value.components(separatedBy:",").count == 4, parts.allSatisfy(\.isFinite) else { return nil }
        let scale = max(abs(parts[1]),abs(parts[2]),abs(parts[3]))
        guard scale > 0 else { return nil }
        degree = parts[0].truncatingRemainder(dividingBy:360)
        x = CGFloat(parts[1]/scale); y = CGFloat(parts[2]/scale); z = CGFloat(parts[3]/scale)
    }
}

struct ScriptWidgetAttributeRotation3DEffectModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scriptWidgetVisualAccessibility) private var preview

    var degree: Double?
    var x: CGFloat = 1
    var y: CGFloat = 0
    var z: CGFloat = 0

    init(_ element: ScriptWidgetRuntimeElement) {

        if let value = element.getPropString("rotation3d"), let rotation = ScriptWidgetRotation3D(value) {
            degree = rotation.degree; x = rotation.x; y = rotation.y; z = rotation.z
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let degree = self.degree, !(preview.reduceMotion ?? reduceMotion) {
            content
                .rotation3DEffect(Angle(degrees: degree), axis: (x: self.x, y: self.y, z: self.z))
        } else {
            content
        }
    }
}
