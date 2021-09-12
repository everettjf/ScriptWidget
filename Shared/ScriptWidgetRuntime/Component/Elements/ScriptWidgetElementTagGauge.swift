//
//  ScriptWidgetElementTagGauge.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/10.
//

import SwiftUI
import SwiftyJSON


/*
 let value = 0.6
 let angle = 260.0
 let sections = [MineGaugeViewSection(color: .green, value: 0.1),
 MineGaugeViewSection(color: .yellow, value: 0.1),
 MineGaugeViewSection(color: .orange, value: 0.1),
 MineGaugeViewSection(color: .red, value: 0.1),
 MineGaugeViewSection(color: .purple, value: 0.2),
 MineGaugeViewSection(color: .blue, value: 0.4)]
 
 struct MineGaugeViewSample: View {
 var body: some View {
 VStack {
 MineGaugeView(angle: angle, value: value,thickness: 10,needleColor:Color.black, sections: sections) {
 VStack {
 Text("\(Int(value * 100)) %").font(.caption)
 Text("Speed").font(.caption)
 }
 }
 }
 }
 }
 <gauge
 angle="260"
 value="0.6"
 thickness="10"
 needleColor="black"
 label="60%" labelFont="caption"
 title="Battery" titleFont="caption"
 sections={$json(gaugeSections)}
 >
 </gauge>
 
 */

class ScriptWidgetElementTagGauge {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        let defaultColor = ScriptWidgetAttributeColor.getThemeDynamicColor(light: Color.black, dark: Color.white)
        
        var value = 0.6
        var angle = 260.0
        var thickness = 10
        var needleColor = defaultColor
        var label = "\(Int(value * 100))%"
        var title = ""
        var labelFont = Font.caption
        var titleFont = Font.caption
        var sections = [
            MineGaugeViewSection(color: .green, value: 0.1),
            MineGaugeViewSection(color: .yellow, value: 0.1),
            MineGaugeViewSection(color: .orange, value: 0.1),
            MineGaugeViewSection(color: .red, value: 0.1),
            MineGaugeViewSection(color: .purple, value: 0.2),
            MineGaugeViewSection(color: .blue, value: 0.4)
        ]
        
        if let valueString = element.getPropString("value") {
            value = Double(valueString) ?? 0.6
        }
        if let valueDouble = element.getPropDouble("value") {
            value = valueDouble
        }
        if value > 1 { value = 1 }
        
        if let angleString = element.getPropString("angle") {
            angle = Double(angleString) ?? 260
        }
        if angle > 360 { angle = 360 }
        
        if let thicknessString = element.getPropString("thickness") {
            thickness = Int(thicknessString) ?? 10
        }
        
        if let needleColorString = element.getPropString("needleColor") {
            let color = ScriptWidgetAttributeColor(needleColorString)
            needleColor = color.color ?? defaultColor
        }
        
        if let labelString = element.getPropString("label") {
            label = labelString
        }
        if let labelFontString = element.getPropString("labelFont") {
            labelFont = ScriptWidgetAttributeFontModifier.getFontFromCustomString(labelFontString) ?? Font.caption;
        }
        
        if let titleString = element.getPropString("title") {
            title = titleString
        }
        if let titleFontString = element.getPropString("titleFont") {
            titleFont = ScriptWidgetAttributeFontModifier.getFontFromCustomString(titleFontString) ?? Font.caption;
        }
        
        if let sectionsString = element.getPropString("sections") {
            if let jsonData = sectionsString.data(using: .utf8)  {
                do {
                    var resultSections = [MineGaugeViewSection]()
                    let json = try JSON(data: jsonData)
                    
                    var leftValue = 100
                    for item in json.arrayValue {
                        let colorString = item["color"].stringValue
                        let valueString = item["value"].stringValue
                        
                        let color = ScriptWidgetAttributeColor(colorString).color ?? defaultColor
                        var value = Double(valueString) ?? 0.0
                        if Int(value*100) > leftValue {
                            value = 0.0
                        }
                        
                        resultSections.append(MineGaugeViewSection(color: color, value: value))

                        leftValue -= Int(value * 100)
                    }
                    
                    sections = resultSections
                } catch {
                    print("json sections parse error : \(error)")
                }
            }
        }

        return AnyView(
            MineGaugeView(angle: angle, value: value,thickness: thickness, needleColor:needleColor, sections: sections) {
                VStack {
                    Text(label)
                        .font(labelFont)
                    Text(title)
                        .font(titleFont)
                }
            }
            .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}

struct ScriptWidgetElementTagGaugeSample: View {
    var body: some View {
        Text("Hello, World!")
    }
}

struct ScriptWidgetElementTagGaugeSample_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetElementTagGaugeSample()
    }
}
