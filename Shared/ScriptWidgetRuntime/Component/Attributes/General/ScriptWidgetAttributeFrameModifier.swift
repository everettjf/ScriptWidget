//
//  ScriptWidgetAttributeFrameModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI

/*
 
 frame="max,topLeading"
 
 */
struct ScriptWidgetAttributeFrameModifier: ViewModifier {
    
    
    enum AttributeFrameMode {
        case none
        case name_alignment
        case width_height_alignment
    }
    
    let frameMode: AttributeFrameMode
    let alignment: Alignment
    let frameName: String // support "max"
    let width: CGFloat
    let height: CGFloat
    
    init(_ element: ScriptWidgetRuntimeElement) {
        var frameMode: AttributeFrameMode = .none
        var frameName: String = ""
        var alignment: Alignment = .center
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        if let frameValue = element.getPropString("frame") {
            let parts = frameValue.split(separator: ",")
            if parts.count == 1 {
                // frameName=max
                frameName = frameValue
                frameMode = .name_alignment
            } else if parts.count == 2 {
                let part1 = String(parts[0])
                let part2 = String(parts[1])
                
                if let widthValue = Double(part1), let heightValue = Double(part2) {
                    // width,height
                    // 10,20
                    width = CGFloat(widthValue)
                    height = CGFloat(heightValue)
                    frameMode = .width_height_alignment
                } else {
                    // max,topLeading
                    frameName = part1
                    alignment = ScriptWidgetAttributeFrameModifier.getAligmentFromName(part2)
                    frameMode = .name_alignment
                }
            } else if parts.count == 3 {
                // width,height,alignment
                // 10,20,topLeading
                let part1 = String(parts[0])
                let part2 = String(parts[1])
                let part3 = String(parts[2])
                
                if let widthValue = Double(part1), let heightValue = Double(part2) {
                    width = CGFloat(widthValue)
                    height = CGFloat(heightValue)
                    alignment = ScriptWidgetAttributeFrameModifier.getAligmentFromName(part3)
                    frameMode = .width_height_alignment
                }
            }
        }
        self.frameMode = frameMode
        self.frameName = frameName
        self.alignment = alignment
        self.width = width
        self.height = height
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if frameMode == .some(.name_alignment) && frameName == "max" {
            content
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: alignment)
        } else if frameMode == .some(.width_height_alignment) {
            content
                .frame(width: width, height: height, alignment: alignment)
        } else {
            content
        }
    }
    
    static func getAligmentFromName(_ name: String) -> Alignment {
        switch name {
        case "center": return .center
        case "leading": return .leading
        case "trailing": return .trailing
        case "top": return .top
        case "bottom": return .bottom
        case "topLeading": return .topLeading
        case "topTrailing": return .topTrailing
        case "bottomLeading": return .bottomLeading
        case "bottomTrailing": return .bottomTrailing
        default: return .center
        }
    }
}

