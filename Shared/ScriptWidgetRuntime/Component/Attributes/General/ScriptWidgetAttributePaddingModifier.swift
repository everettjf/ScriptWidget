//
//  ScriptWidgetAttributePaddingModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI

struct ScriptWidgetAttributePaddingModifier: ViewModifier {
    
    let mode: Int
    
    // mode value = 1
    let paddingAll: CGFloat
    
    // mode value = 2
    let paddingEdgeType: Edge.Set
    let paddingEdge: CGFloat
    
    // mode value = 4
    let paddingTop: CGFloat
    let paddingTrailing: CGFloat
    let paddingBottom: CGFloat
    let paddingLeading: CGFloat
    
    init(_ element: ScriptWidgetRuntimeElement) {
        var tmpMode: Int = 0
        
        // 1 mode
        var tmpPaddingAll: CGFloat = 10
        
        // 2 mode
        var tmpPaddingEdgeType: Edge.Set = .all
        var tmpPaddingEdge: CGFloat = 10
        
        // 4 mode
        var tmpPaddingTop: CGFloat = 10
        var tmpPaddingTrailing: CGFloat = 10
        var tmpPaddingBottom: CGFloat = 10
        var tmpPaddingLeading: CGFloat = 10
        
        if let paddingValue = element.getPropString("padding")  {
            
            let parts = paddingValue.split(separator: ",")
            if parts.count == 1 {
                // 10
                tmpMode = 1
                tmpPaddingAll = CGFloat(Double(paddingValue) ?? 0)
            } else if parts.count == 2 {
                // top,10
                tmpMode = 2
                
                let edgeValue = parts[0]
                let numberValue = parts[1]
                tmpPaddingEdge = CGFloat(Double(numberValue) ?? 0)

                switch edgeValue {
                case "top": tmpPaddingEdgeType = .top
                case "leading": tmpPaddingEdgeType = .leading
                case "bottom": tmpPaddingEdgeType = .bottom
                case "trailing": tmpPaddingEdgeType = .trailing
                case "all": tmpPaddingEdgeType = .all
                case "horizontal": tmpPaddingEdgeType = .horizontal
                case "vertical": tmpPaddingEdgeType = .vertical
                default: tmpPaddingEdgeType = .all
                }
                
            } else if parts.count == 4 {
                // 10,20,30,40
                tmpMode = 4
                tmpPaddingTop = CGFloat(Double(parts[0]) ?? 0)
                tmpPaddingTrailing = CGFloat(Double(parts[1]) ?? 0)
                tmpPaddingBottom = CGFloat(Double(parts[2]) ?? 0)
                tmpPaddingLeading = CGFloat(Double(parts[3]) ?? 0)
            } else {
                // error
            }
        }
        
        mode = tmpMode
        
        paddingAll = tmpPaddingAll
        
        paddingEdgeType = tmpPaddingEdgeType
        paddingEdge = tmpPaddingEdge
        
        paddingTop = tmpPaddingTop
        paddingTrailing = tmpPaddingTrailing
        paddingBottom = tmpPaddingBottom
        paddingLeading = tmpPaddingLeading
        
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if mode == 1 {
            content
                .padding(paddingAll)
        } else if mode == 2 {
            content
                .padding(paddingEdgeType, paddingEdge)
        } else if mode == 4 {
            content
                .padding(.top, paddingTop)
                .padding(.trailing, paddingTrailing)
                .padding(.bottom, paddingBottom)
                .padding(.leading, paddingLeading)
        } else {
            content
        }
    }
    
}
