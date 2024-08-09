//
//  ScriptWidgetElementTagGauge.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/10.
//

import SwiftUI
import SwiftyJSON


struct ScriptWidgetGaugeStyleModifier : ViewModifier {
    let gaugeStyle: String
    
    init(_ gaugeStyle: String) {
        self.gaugeStyle = gaugeStyle
    }
    
    func body(content: Content) -> some View {
        if gaugeStyle == "circular" {
            content.gaugeStyle(.accessoryCircular)
        } else if gaugeStyle == "linear" {
            content.gaugeStyle(.accessoryLinear)
        } else if gaugeStyle == "automatic" {
            content.gaugeStyle(.automatic)
        } else {
            content.gaugeStyle(.automatic)
        }
    }
}

class ScriptWidgetElementTagGauge {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        let gaugeType = element.getPropString("type") ?? "original"
        if (gaugeType == "original") {
            return Self.buildOriginal(element, context)
        }
        return Self.buildSystem(element, context)
    }
    static func buildSystem(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        let value = Double(element.getPropString("value") ?? "0.6") ?? 0.6
        let gaugeStyle = element.getPropString("style") ?? "circular"
        
        let text = element.getPropString("text") ?? ""
        let current = element.getPropString("current") ?? ""
        let min = element.getPropString("min") ?? ""
        let max = element.getPropString("max") ?? ""
        
        if min.count > 0 {
            return AnyView(
                Gauge(value: value) {
                    Text(text)
                } currentValueLabel: {
                    Text(current)
                } minimumValueLabel: {
                    Text(min)
                } maximumValueLabel: {
                    Text(max)
                }
                .modifier(ScriptWidgetGaugeStyleModifier(gaugeStyle))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
            )
        } else {
            return AnyView(
                Gauge(value: value) {
                    Text(text)
                } currentValueLabel: {
                    Text(current)
                }
                .modifier(ScriptWidgetGaugeStyleModifier(gaugeStyle))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
            )
        }

    }
    
    static func buildOriginal(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        let defaultColor = ScriptWidgetAttributeColor.getThemeDynamicColor(light: Color.black, dark: Color.white)
        
        var value = 0.6
        var angle = 260.0
        var thickness = 10
        var needleColor = defaultColor
        var label = "\(Int(value * 100))%"
        var title = ""
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
        
        if let titleString = element.getPropString("title") {
            title = titleString
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
                        .modifier(ScriptWidgetAttributeFontModifier(element, fontField: "labelFont"))
                        .modifier(ScriptWidgetAttributeForegroundModifier(element, colorField: "labelColor"))
                    Text(title)
                        .modifier(ScriptWidgetAttributeFontModifier(element, fontField: "labelFont"))
                        .modifier(ScriptWidgetAttributeForegroundModifier(element, colorField: "titleColor"))
                }
            }
            .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}

struct ScriptWidgetElementTagGaugeSample: View {
    
    @State private var current = 67.0
    @State private var minValue = 0.0
    @State private var maxValue = 170.0
    
    var body: some View {
        VStack {
            Gauge(value: 0.6) {
                Text("Battery")
            } currentValueLabel: {
                Text("hello")
            } minimumValueLabel: {
            } maximumValueLabel: {
            }
            .gaugeStyle(.accessoryCircular)
            
            Gauge(value: current, in: minValue...maxValue) {
                Text("BPM")
            } currentValueLabel: {
                Text("\(Int(current))")
            } minimumValueLabel: {
                Text("\(Int(minValue))")
            } maximumValueLabel: {
                Text("\(Int(maxValue))")
            }
            .gaugeStyle(.accessoryLinear)
            
            Gauge(value: current) {
                Text("60")
            }
            .gaugeStyle(.accessoryCircular)
            
            Gauge(value: current) {
                Text("")
            } currentValueLabel: {
                Text("")
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text("")
            }
            .gaugeStyle(.accessoryCircular)

        }
    }
}

struct ScriptWidgetElementTagGaugeSample_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetElementTagGaugeSample()
    }
}
