//
//  ScriptWidgetElementView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/31.
//

import SwiftUI

struct ScriptWidgetElementContext {
    let debugMode: Bool
}

struct ScriptWidgetElementView: View {
    
    let element: ScriptWidgetRuntimeElement
    let context: ScriptWidgetElementContext
    
    var body: some View {
        AnyView(ScriptWidgetElementView.buildView(element: element, context: context))
            .widgetURL(ScriptWidgetElementTagLink.getDestination("linkurl", element))
    }
    
    static func buildView(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> AnyView {
        switch element.tag {
        case "text": return ScriptWidgetElementTagText.buildView(element, context)
        case "date": return ScriptWidgetElementTagDate.buildView(element, context)
        case "image": return ScriptWidgetElementTagImage.buildView(element, context)
        case "spacer": return ScriptWidgetElementTagSpacer.buildView(element, context)
        case "hstack": return ScriptWidgetElementTagHStack.buildView(element, context)
        case "vstack": return ScriptWidgetElementTagVStack.buildView(element, context)
        case "zstack": return ScriptWidgetElementTagZStack.buildView(element, context)
        case "rect": return ScriptWidgetElementTagRectangle.buildView(element, context)
        case "capsule": return ScriptWidgetElementTagCapsule.buildView(element, context)
        case "ellipse": return ScriptWidgetElementTagEllipse.buildView(element, context)
        case "circle": return ScriptWidgetElementTagCircle.buildView(element, context)
        case "gauge": return ScriptWidgetElementTagGauge.buildView(element, context)
        case "link": return ScriptWidgetElementTagLink.buildView(element, context)
        default: return AnyView(Text("UnknownTag").background(Color.red))
        }
    }
}

struct ScriptWidgetElementView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetElementView(
            element: ScriptWidgetRuntimeElement(tag: "text", props: nil, children: ["Hello SwiftWidget"]),
            context: ScriptWidgetElementContext(debugMode: true)
        )
    }
}
