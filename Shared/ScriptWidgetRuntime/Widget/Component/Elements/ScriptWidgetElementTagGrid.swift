//
//  ScriptWidgetElementTagGrid.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/3/2.
//

import Foundation
import SwiftUI
import SwiftyJSON

class ScriptWidgetElementTagGrid {
    
    ///--------------------------------------------------------------------------------------------------------
    static func buildViewVGrid(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(Self.buildVGrid(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder private static func buildVGrid(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        LazyVGrid(columns: Self.getColumnsOrRows(element), alignment: Self.getHorizontalAlignment(element), spacing: Self.getSpacing(element)) {
            ForEach(element.childrenAsElements()) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    ///--------------------------------------------------------------------------------------------------------
    
    static func buildViewHGrid(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(Self.buildHGrid(
            element: element,
            context: context
        ))
    }
    
    @ViewBuilder private static func buildHGrid(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> some View {
        LazyHGrid(rows: Self.getColumnsOrRows(element), alignment: Self.getVerticalAlignment(element), spacing: Self.getSpacing(element)) {
            ForEach(element.childrenAsElements()) { item -> AnyView in
                return ScriptWidgetElementView.buildView(element: item, context: context)
            }
        }
        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
    }
    
    ///--------------------------------------------------------------------------------------------------------
        
    static func getColumnsOrRows(_ element: ScriptWidgetRuntimeElement) -> [GridItem] {
#if os(macOS)
        let defaultColumns = [GridItem(.adaptive(minimum: 30, maximum: 100))]
#else
        let defaultColumns = [GridItem(.adaptive(minimum: 30))]
#endif
        guard let columnString = element.getPropString("columns") else {
            return defaultColumns
        }
        
        guard let jsonData = columnString.data(using: .utf8) else {
            return defaultColumns
        }
        
        do {
            var resultColumns = [GridItem]()
            let json = try JSON(data: jsonData)
            
            for jsonItem in json.arrayValue {
                
                /*
                 iOS
                 { type: "adaptive", min: "30"},
                 { type: "fixed", value: "30"},
                 { type: "flexible"},
                 
                 macOS
                 { type: "adaptive", min: "30", max: "100"},
                 { type: "fixed", value: "30"},
                 { type: "flexible"},
                 */
                
                let typeString = jsonItem["type"].stringValue
                if typeString == "flexible" {
                    resultColumns.append(GridItem(.flexible()))
                } else if typeString == "fixed" {
                    let value = Double(jsonItem["value"].stringValue) ?? 10
                    resultColumns.append(GridItem(.fixed(value)))
                } else if typeString == "adaptive" {
                    let min = Double(jsonItem["min"].stringValue) ?? 10
                    let max = Double(jsonItem["max"].stringValue) ?? 10
                    resultColumns.append(GridItem(.adaptive(minimum: min, maximum: max)))
                } else {
                    resultColumns.append(GridItem(.flexible()))
                }
            }
            
            return resultColumns
        } catch {
            print("grid column error \(error)")
        }
        
        return defaultColumns
    }
    
    
        
    static func getHorizontalAlignment(_ element: ScriptWidgetRuntimeElement) -> HorizontalAlignment {
        guard let alignment = element.getPropString("alignment") else { return .center }
        
        switch alignment {
        case "leading": return .leading
        case "trailing": return .trailing
        case "center": return .center
        default: return .center
        }
    }
    
    static func getVerticalAlignment(_ element: ScriptWidgetRuntimeElement) -> VerticalAlignment {
        guard let alignment = element.getPropString("alignment") else { return .center }
        
        switch alignment {
        case "top": return .top
        case "bottom": return .bottom
        case "center": return .center
        case "firstTextBaseline": return .firstTextBaseline
        case "lastTextBaseline": return .lastTextBaseline
        default: return .center
        }
    }
    
    static func getSpacing(_ element: ScriptWidgetRuntimeElement) -> CGFloat? {
        guard let spacing = element.getPropDouble("spacing") else { return nil }
        return CGFloat(spacing)
    }
}
