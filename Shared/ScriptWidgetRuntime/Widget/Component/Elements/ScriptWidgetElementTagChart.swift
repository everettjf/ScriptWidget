//
//  ScriptWidgetElementTagChart.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/11.
//

import SwiftUI
import Charts


struct ScriptWidgetChartSharedAttribute {
    let categoryEnabled: Bool
    let hideLegend: Bool
    let hideXAxis: Bool
    let hideYAxis: Bool
}

struct ScriptWidgetElementTagChartForgroundStyleScaleModifier : ViewModifier {
    let foregroundStyleValueMap: KeyValuePairs<String, Color>
    
    struct CategoryColorJsonItem: Decodable {
        let category: String
        let color: String
    }
    
    init(categoryColor: String) {
        guard let jsonData = categoryColor.data(using: .utf8) else {
            foregroundStyleValueMap = [:]
            return
        }
        
        guard let items: [CategoryColorJsonItem] = try? JSONDecoder().decode([CategoryColorJsonItem].self, from: jsonData) else {
            foregroundStyleValueMap = [:]
            return
        }
        
        var valueMap: [String: Color] = [:]
        for item in items {
            let color = ScriptWidgetAttributeColor(item.color)
            valueMap[item.category] = color.color ?? .blue
        }
        // TODO
        //        self.foregroundStyleValueMap = valueMap as KeyValuePairs
        foregroundStyleValueMap = [:]
    }
    
    func body(content: Content) -> some View {
        if foregroundStyleValueMap.isEmpty {
            content
        } else {
            content
                .chartForegroundStyleScale(foregroundStyleValueMap)
        }
    }
}



class ScriptWidgetElementTagChart {
    
    struct ChartJsonItem: Identifiable, Decodable {
        let id = UUID()
        let label: String
        let value: Double
        let category: String?
        
        private enum CodingKeys: String, CodingKey {
            case label, value, category
        }
    }
    
    struct ChartBarGanttJsonItem: Identifiable, Decodable {
        let id = UUID()
        let job: String
        let start: Double
        let end: Double
        let category: String?
        
        private enum CodingKeys: String, CodingKey {
            case job, start, end, category
        }
    }
    struct ChartRuleJsonItem: Identifiable, Decodable {
        let id = UUID()
        let xstart: Double
        let xend: Double
        let y: Double
        let category: String?
        
        private enum CodingKeys: String, CodingKey {
            case xstart, xend, y, category
        }
    }
    
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(
            Self.buildChart(element, context)
                .modifier(ScriptWidgetAttributeForegroundModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
    
    static private func buildChart(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        let type = element.getPropString("type") ?? "bar"
        let data = element.getPropString("data") ?? ""
        if data.count == 0 {
            return AnyView(Text("#chart no data#"))
        }
        
        guard let jsonData = data.data(using: .utf8) else {
            return AnyView(Text("#chart data invalid#"))
        }
        
        let sharedAttribute = ScriptWidgetChartSharedAttribute(
            categoryEnabled: element.getPropBool("category") ?? false,
            hideLegend: element.getPropBool("hideLegend") ?? false,
            hideXAxis: element.getPropBool("hideXAxis") ?? false,
            hideYAxis: element.getPropBool("hideYAxis") ?? false
        )
        
        switch type {
        case "bar": return Self.buildChartBar(element, context, jsonData, sharedAttribute)
        case "bar-x": return Self.buildChartBarX(element, context, jsonData, sharedAttribute)
        case "bar-y": return Self.buildChartBarY(element, context, jsonData, sharedAttribute)
        case "bar-gantt": return Self.buildChartBarGantt(element, context, jsonData, sharedAttribute)
        case "line": return Self.buildChartLine(element, context, jsonData, sharedAttribute)
        case "point": return Self.buildChartPoint(element, context, jsonData, sharedAttribute)
        case "line-point": return Self.buildChartLinePoint(element, context, jsonData, sharedAttribute)
        case "area": return Self.buildChartArea(element, context, jsonData, sharedAttribute)
        case "rect": return Self.buildChartRect(element, context, jsonData, sharedAttribute)
        case "rule-x": return Self.buildChartRule(element, context, jsonData, sharedAttribute)
        default: return AnyView(Text("#unknown chart type#"))
        }
    }
    static private func buildChartBar(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            
            return AnyView(
                Chart(items) {
                    BarMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        
        return AnyView(
            Chart(items) {
                BarMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    
    static private func buildChartBarX(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    BarMark(
                        x: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        
        return AnyView(
            Chart(items) {
                BarMark(
                    x: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    
    static private func buildChartBarY(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    BarMark(
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        
        return AnyView(
            Chart(items) {
                BarMark(
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    static private func buildChartBarGantt(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartBarGanttJsonItem] = try? JSONDecoder().decode([ChartBarGanttJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            
            return AnyView(
                Chart(items) {
                    BarMark(
                        xStart: .value("Start Time", $0.start),
                        xEnd: .value("End Time", $0.end),
                        y: .value("Job", $0.job)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                BarMark(
                    xStart: .value("Start Time", $0.start),
                    xEnd: .value("End Time", $0.end),
                    y: .value("Job", $0.job)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    static private func buildChartLine(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    LineMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                LineMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    static private func buildChartPoint(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    PointMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                PointMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    static private func buildChartLinePoint(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                
                Chart(items) {
                    
                    LineMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                    PointMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                LineMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
                PointMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    static private func buildChartArea(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    AreaMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                AreaMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    
    static private func buildChartRect(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartJsonItem] = try? JSONDecoder().decode([ChartJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView(
                Chart(items) {
                    RectangleMark(
                        x: .value("Label", $0.label),
                        y: .value("Value", $0.value)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                RectangleMark(
                    x: .value("Label", $0.label),
                    y: .value("Value", $0.value)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
    
    static private func buildChartRule(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext, _ jsonData: Data, _ sharedAttribute: ScriptWidgetChartSharedAttribute) -> AnyView {
        
        guard let items: [ChartRuleJsonItem] = try? JSONDecoder().decode([ChartRuleJsonItem].self, from: jsonData) else {
            return AnyView(Text("#chart data json invalid#"))
        }
        if sharedAttribute.categoryEnabled {
            return AnyView (
                Chart(items) {
                    RuleMark(
                        xStart: .value("Start", $0.xstart),
                        xEnd: .value("End", $0.xend),
                        y: .value("Value", $0.y)
                    )
                    .foregroundStyle(by: .value("Category", $0.category ?? "null"))
                }
                    .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                    .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                    .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
            )
        }
        return AnyView(
            Chart(items) {
                RuleMark(
                    xStart: .value("Start", $0.xstart),
                    xEnd: .value("End", $0.xend),
                    y: .value("Value", $0.y)
                )
            }
                .chartLegend(sharedAttribute.hideLegend ? .hidden : .automatic)
                .chartXAxis(sharedAttribute.hideXAxis ? .hidden : .automatic)
                .chartYAxis(sharedAttribute.hideYAxis ? .hidden : .automatic)
        )
    }
}


struct ScriptWidgetElementTagChart_Previews: PreviewProvider {
    
    struct MountPrice: Identifiable {
        var id = UUID()
        var mount: String
        var value: Double
    }
    struct ProfitByCategory: Identifiable {
        var id = UUID()
        let department: String
        let profit: Double
        let productCategory: String
    }
    
    static let data: [MountPrice] = [
        MountPrice(mount: "jan/22", value: 5),
        MountPrice(mount: "feb/22", value: 4),
        MountPrice(mount: "mar/22", value: 7),
        MountPrice(mount: "apr/22", value: 15),
        MountPrice(mount: "may/22", value: 14),
        MountPrice(mount: "jun/22", value: 27),
        MountPrice(mount: "jul/22", value: 27)
    ]
    
    static let data2: [ProfitByCategory] = [
        ProfitByCategory(department: "Production", profit: 4000, productCategory: "Gizmos"),
        ProfitByCategory(department: "Production", profit: 5000, productCategory: "Gadgets"),
        ProfitByCategory(department: "Production", profit: 6000, productCategory: "Widgets"),
        ProfitByCategory(department: "Marketing", profit: 2000, productCategory: "Gizmos"),
        ProfitByCategory(department: "Marketing", profit: 1000, productCategory: "Gadgets"),
        ProfitByCategory(department: "Marketing", profit: 5000.9, productCategory: "Widgets"),
        ProfitByCategory(department: "Finance", profit: 2000.5, productCategory: "Gizmos"),
        ProfitByCategory(department: "Finance", profit: 3000, productCategory: "Gadgets"),
        ProfitByCategory(department: "Finance", profit: 5000, productCategory: "Widgets")
    ]
    static var previews: some View {
        List {
            Chart(data2) {
                BarMark(
                    x: .value("Category", $0.department),
                    y: .value("Profit", $0.profit)
                )
            }
            .foregroundColor(.red)
            .frame(height: 250)
            
            Chart(data2) { // Get the Production values.
                BarMark(
                    x: .value("Profit", $0.profit)
                )
                //                .foregroundStyle(by: .value("Product Category", $0.productCategory))
            }
            .frame(height: 100)
            Chart(data2) { // Get the Production values.
                BarMark(
                    y:.value("Profit", $0.profit)
                )
                .foregroundStyle(by: .value("Product Category", $0.productCategory))
            }
            .frame(height: 100)
            //            Chart(data2) {
            //                BarMark(
            //                    x: .value("Category", $0.department),
            //                    y: .value("Profit", $0.profit)
            //                )
            //                .foregroundStyle(by: .value("Product Category", $0.productCategory))
            //            }
            //            .frame(height: 250)
        }
        //        List {
        //            Chart {
        //                BarMark(
        //                    x: .value("Mount", "jan/22"),
        //                    y: .value("Value", 5)
        //                )
        //                BarMark(
        //                    x: .value("Mount", "fev/22"),
        //                    y: .value("Value", 4)
        //                )
        //                BarMark(
        //                    x: .value("Mount", "mar/22"),
        //                    y: .value("Value", 7)
        //                )
        //            }
        //            .frame(height: 250)
        //
        //            Chart {
        //                LineMark(
        //                    x: .value("Mount", "jan/22"),
        //                    y: .value("Value", 5)
        //                )
        //                LineMark(
        //                    x: .value("Mount", "fev/22"),
        //                    y: .value("Value", 4)
        //                )
        //                LineMark(
        //                    x: .value("Mount", "mar/22"),
        //                    y: .value("Value", 7)
        //                )
        //            }
        //            .frame(height: 250)
        //
        //            Chart {
        //                PointMark(
        //                    x: .value("Mount", "jan/22"),
        //                    y: .value("Value", 5)
        //                )
        //                PointMark(
        //                    x: .value("Mount", "fev/22"),
        //                    y: .value("Value", 4)
        //                )
        //                PointMark(
        //                    x: .value("Mount", "mar/22"),
        //                    y: .value("Value", 7)
        //                )
        //            }
        //            .frame(height: 250)
        //        }
        //
        //        List {
        //            Chart {
        //                AreaMark(
        //                    x: .value("1", "jan/22"),
        //                    y: .value("Value", 5)
        //                )
        //                AreaMark(
        //                    x: .value("2", "fev/22"),
        //                    y: .value("Value", 4)
        //                )
        //                AreaMark(
        //                    x: .value("3", "mar/22"),
        //                    y: .value("Value", 7)
        //                )
        //            }
        //            .frame(height: 250)
        //            Chart {
        //                RectangleMark(
        //                    x: .value("Mount", "jan/22"),
        //                    y: .value("Value", 5)
        //                )
        //                RectangleMark(
        //                    x: .value("Mount", "fev/22"),
        //                    y: .value("Value", 4)
        //                )
        //                RectangleMark(
        //                    x: .value("Mount", "mar/22"),
        //                    y: .value("Value", 7)
        //                )
        //            }
        //            .frame(height: 250)
        //        }
        //
        //        List {
        //            Chart {
        //                RuleMark(
        //                    xStart: .value("Start", 1),
        //                    xEnd: .value("End", 12),
        //                    y: .value("Value", 2.5)
        //                )
        //                RuleMark(
        //                    xStart: .value("Start", 9),
        //                    xEnd: .value("End", 16),
        //                    y: .value("Value", 1.5)
        //                )
        //                RuleMark(
        //                    xStart: .value("Start", 3),
        //                    xEnd: .value("End", 10),
        //                    y: .value("Value", 0.5)
        //                )
        //            }
        //            .frame(height: 250)
        //
        //            Chart(data) {
        //                LineMark(
        //                    x: .value("Mount", $0.mount),
        //                    y: .value("Value", $0.value)
        //                )
        //                PointMark(
        //                    x: .value("Mount", $0.mount),
        //                    y: .value("Value", $0.value)
        //                )
        //            }
        //            .frame(height: 250)
        //        }
    }
}
