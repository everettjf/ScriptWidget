//
//  ScriptWidgetElementTagDate.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation
import SwiftUI


class ScriptWidgetElementTagDate {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        var dateStyle: Text.DateStyle = .timer
        if let style = element.getPropString("style") {
            dateStyle = ScriptWidgetElementTagDate.getStyle(styleName: style)
        }
        
        var date: Date = Date()
        if let dateName = element.getPropString("date") {
            date = ScriptWidgetElementTagDate.getDate(dateName: dateName)
        } else if let dateTimestamp = element.getPropDouble("date") {
            date = Date(timeIntervalSince1970: dateTimestamp / 1000.0)
        }
        
        return AnyView(
            Text(date ,style: dateStyle)
                .modifier(ScriptWidgetAttributeTextModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
    
    static func getDate(dateName: String) -> Date {
        switch dateName {
        case "now": return Date()
        case "tomorrow": return Date().advanced(by: 1*24*60*60)
        case "yesterday": return Date().advanced(by: -1*24*60*60)
        case "start of today": return Calendar.current.startOfDay(for: Date())
        default: return Date()
        }
    }
    
    static func getStyle(styleName: String) -> Text.DateStyle {
        switch styleName {
        case "time": return .time
        case "date": return .date
        case "relative": return .relative
        case "offset": return .offset
        case "timer": return .timer
        default: return .time
        }
    }
}
struct FixedClipped: ViewModifier {
    let width: CGFloat
    let height: CGFloat
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .frame(width:width, height:height)
                .hidden()
                .layoutPriority(1)
            content
                .fixedSize(horizontal: true, vertical: false)
        }
        .clipped()
    }
}


struct ScriptWidgetElementDateSampleView: View {
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()
    
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
//            // 11:23PM
//            Text(Date(), style: .time)
//
//            // June 3, 2019
//            Text(Date(), style: .date)
//
//            // 2 hours, 23 minutes
//            // 1 year, 1 month
//            Text(Date(), style: .relative)
//
//            // +2 hours
//            // -3 months
//            Text(Date(), style: .offset)
//
//            // 2:32
//            // 36:59:01
//            Text(Date().addingTimeInterval(600), style: .timer)
//            // 22:14:40
//            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
            
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(Font.custom("Apple ][", size: 17))
                .background(Color.yellow)
            
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(Font.custom("Apple ][", size: 17))
                .modifier(FixedClipped(width: 35, height: 50))
                .background(Color.yellow)
            
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(Font.custom("iconfont-widget-cartoon-hand", size: 50))
                .modifier(FixedClipped(width: 50, height: 50))
                .background(Color.yellow)
            
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(Font.custom("iconfont-widget-8bit-colon", size: 50))
                .modifier(FixedClipped(width: 50, height: 50))
                .background(Color.yellow)
            
            Text(Calendar.current.startOfDay(for: Date()), style: .timer)
                .font(Font.custom("everettjf-UpDownLine", size: 50))
                .modifier(FixedClipped(width: 30, height: 50))
                .background(Color.yellow)
        }
    }
}

struct ScriptWidgetElementDateSampleView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetElementDateSampleView()
            .preferredColorScheme(.light)
            .previewLayout(.sizeThatFits)
        
        
    }
}
