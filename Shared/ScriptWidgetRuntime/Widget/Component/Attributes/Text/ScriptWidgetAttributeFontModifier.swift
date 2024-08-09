//
//  ScriptWidgetAttributeFontModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI


struct ScriptWidgetAttributeFontModifier: ViewModifier {
    
    let font: Font?
    
    init(_ element: ScriptWidgetRuntimeElement, fontField: String) {
        var font: Font? = nil
        if let fontValue = element.getPropString(fontField) {
            font = ScriptWidgetAttributeFontModifier.getFontFromCustomString(fontValue);
        }
        self.font = font
    }
    
    init(_ element: ScriptWidgetRuntimeElement) {
        self.init(element, fontField: "font")
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if let font = self.font {
            content
                .font(font)
        } else {
            content
        }
    }
    
    static func getFontFromCustomString(_ fontString: String) -> Font? {
        var font: Font? = nil
        var weight: Font.Weight? = nil
        let parts = fontString.split(separator: ",")
        if parts.count == 1 {
            font = ScriptWidgetAttributeFontModifier.getFontFromStringName(fontString,nil)
        } else if parts.count == 2 {
            let fontName = String(parts[0])
            let weightName = String(parts[1])
            font = ScriptWidgetAttributeFontModifier.getFontFromStringName(fontName,nil)
            weight = ScriptWidgetAttributeFontModifier.getFontWeightFromStringName(weightName)
        } else if parts.count == 3 {
            let fontName = String(parts[0])
            if fontName == "custom" {
                let customFontName = String(parts[1])
                let customFontSize = String(parts[2])
                let fontSize : CGFloat = Double(customFontSize) ?? 10
                font = .custom(customFontName, size: fontSize)
            } else {
                let weightName = String(parts[1])
                let designName = String(parts[2])
                font = ScriptWidgetAttributeFontModifier.getFontFromStringName(fontName, designName)
                weight = ScriptWidgetAttributeFontModifier.getFontWeightFromStringName(weightName)
            }
        } else {
            // error
        }
        if let weight = weight {
            font = font?.weight(weight)
        }
        
        return font
    }
    
    
    static func getFontFromStringName(_ name: String, _ designName: String?) -> Font? {
        var font: Font? = nil
        switch name {
        case "largeTitle": font = .largeTitle
        case "title" : font = .title
        case "title2": font = .title2
        case "title3": font = .title3
        case "headline": font = .headline
        case "subheadline": font = .subheadline
        case "body": font = .body
        case "callout": font = .callout
        case "footnote": font = .footnote
        case "caption": font = .caption
        case "caption2": font = .caption2
        default: font = nil
        }
        
        if font == nil {
            if let fontSize = Double(name) {
                if let designName = designName, let design = Self.getFontDesignFromStringName(designName)  {
                    font = .system(size: 20, weight: .regular, design: design)
                } else {
                    font = .system(size: CGFloat(fontSize))
                }
            }
        }
        
        return font
    }
    static func getFontWeightFromStringName(_ name: String) -> Font.Weight? {
        var weight: Font.Weight? = nil
        switch name {
        case "ultraLight": weight = .ultraLight
        case "thin": weight = .thin
        case "light": weight = .light
        case "regular": weight = .regular
        case "medium": weight = .medium
        case "semibold": weight = .semibold
        case "bold": weight = .bold
        case "heavy": weight = .heavy
        case "black": weight = .black
        default: weight = nil
        }
        return weight
    }
    
    static func getFontDesignFromStringName(_ name: String) -> Font.Design? {
        var design: Font.Design? = nil
        switch name {
        case "monospaced": design = .monospaced
        case "rounded": design = .rounded
        case "serif": design = .serif
        case "default": design = .`default`
        default: design = nil
        }
        return design
    }
}
