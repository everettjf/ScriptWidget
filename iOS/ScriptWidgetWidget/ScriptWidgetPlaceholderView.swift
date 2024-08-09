//
//  ScriptWidgetPlaceholderView.swift
//  ScriptWidgetWidget
//
//  Created by everettjf on 2021/3/1.
//

import SwiftUI
import WidgetKit

struct ScriptWidgetPlaceholderView: View {
    
    let widgetFamily: WidgetFamily
    
    
    var normal: some View {
        
        VStack (spacing: 20) {
            Image(systemName: "lessthan")
                .font(.system(size: 50, weight: .bold, design: .monospaced))
            
            Text("ScriptWidget")
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(Color.gray.opacity(0.75))
        .padding()
    }
    
    var small: some View {
        HStack {
            Image(systemName: "lessthan")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            Text("ScriptWidget")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
    }
    var inline: some View {
        HStack {
            Image(systemName: "lessthan")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
            Text("Build widgets with JavaScript")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
        }
    }
    var circle: some View {
        Gauge(value: 0.7) {
            Text("<")
        } currentValueLabel: {
            Text("ScriptWidget")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircular)
    }

    var body: some View {
        Group {
            switch widgetFamily {
            case .systemSmall:
                normal
            case .systemMedium:
                normal
            case .systemLarge:
                normal
            case .systemExtraLarge:
                normal
            case .accessoryCorner:
                small
            case .accessoryCircular:
                circle
            case .accessoryRectangular:
                small
            case .accessoryInline:
                inline
            default:
                normal
            }
        }
    }
}

struct ScriptWidgetPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetPlaceholderView(widgetFamily: .systemSmall)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("systemSmall")
        ScriptWidgetPlaceholderView(widgetFamily: .systemMedium)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("systemMedium")
        ScriptWidgetPlaceholderView(widgetFamily: .systemLarge)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("systemLarge")
        ScriptWidgetPlaceholderView(widgetFamily: .systemExtraLarge)
            .previewContext(WidgetPreviewContext(family: .systemExtraLarge))
            .previewDisplayName("systemExtraLarge")
        ScriptWidgetPlaceholderView(widgetFamily: .accessoryInline)
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("accessoryInline")
        ScriptWidgetPlaceholderView(widgetFamily: .accessoryCircular)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("accessoryCircular")
        ScriptWidgetPlaceholderView(widgetFamily: .accessoryRectangular)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("accessoryRectangular")
    }
}
