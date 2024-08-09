//
//  ScriptWidgetElementView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/31.
//

import SwiftUI

class ScriptWidgetElementContext {
    let debugMode: Bool
    let scriptName: String
    let scriptParameter: String
    let package: ScriptWidgetPackage
    
    weak var runtime: ScriptWidgetRuntime?
        
    init(runtime: ScriptWidgetRuntime? ,debugMode: Bool, scriptName: String, scriptParameter: String, package: ScriptWidgetPackage) {
        self.runtime = runtime
        self.debugMode = debugMode
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        self.package = package
    }
}

class ScriptWidgetElementViewStateObject: ObservableObject {
    // reserved
}

struct ScriptWidgetElementView: View {
    
    let element: ScriptWidgetRuntimeElement
    let context: ScriptWidgetElementContext
    
    @ObservedObject var state = ScriptWidgetElementViewStateObject()
    
    init(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) {
        self.element = element
        self.context = context
    }
    
    var body: some View {
#if os(macOS)
        AnyView(ScriptWidgetElementView.buildView(element: element, context: context))
            .environmentObject(state)
#else
        AnyView(ScriptWidgetElementView.buildView(element: element, context: context))
                .widgetURL(ScriptWidgetElementTagLink.getDestination("linkurl", element))
                .environmentObject(state)
#endif
    }
    
    static func buildView(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> AnyView {
        if let tag = element.tagAsString() {
            print("build tag : \(tag)")
            
            switch tag {
            case "hstack": return ScriptWidgetElementTagStack.buildViewHStack(element, context)
            case "vstack": return ScriptWidgetElementTagStack.buildViewVStack(element, context)
            case "zstack": return ScriptWidgetElementTagZStack.buildView(element, context)
            case "hgrid": return ScriptWidgetElementTagGrid.buildViewHGrid(element, context)
            case "vgrid": return ScriptWidgetElementTagGrid.buildViewVGrid(element, context)
                
            case "text": return ScriptWidgetElementTagText.buildView(element, context)
            case "date": return ScriptWidgetElementTagDate.buildView(element, context)
            case "image": return ScriptWidgetElementTagImage.buildView(element, context)
            case "spacer": return ScriptWidgetElementTagSpacer.buildView(element, context)
            case "rect": return ScriptWidgetElementTagRectangle.buildView(element, context)
            case "capsule": return ScriptWidgetElementTagCapsule.buildView(element, context)
            case "ellipse": return ScriptWidgetElementTagEllipse.buildView(element, context)
            case "circle": return ScriptWidgetElementTagCircle.buildView(element, context)
            case "gauge": return ScriptWidgetElementTagGauge.buildView(element, context)
            case "chart": return ScriptWidgetElementTagChart.buildView(element, context)
            case "link": return ScriptWidgetElementTagLink.buildView(element, context)

            case "button": return ScriptWidgetElementTagButton.buildView(element, context)
            case "toggle": return ScriptWidgetElementTagToggle.buildView(element, context)
                
            default: return Self.unknownStringTagView(element: element, context: context)
            }
        } else {
            print("build tag : unknown type")
            
            return Self.unknownTypeTagView(element: element, context: context)
        }
    }
    
    static func unknownTypeTagView(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> AnyView {
        // search custom tag
        if let runtime = context.runtime {
            let tagType = runtime.getTypeOfValue(element.tag)
            print("tag type = \(tagType)")
            if tagType == "function" {
                let builder = element.tag
                var argument = [AnyHashable:Any]()
                for (prop,value) in element.getProps() {
                    argument[prop] = value
                }
                argument["children"] = element.getChildren()
                if let resultValue = builder.call(withArguments: [argument]) {
                    if resultValue.isObject {
                        let resultObject = resultValue.toObject()
                        if let resultElement = resultObject as? ScriptWidgetRuntimeElement {
                            return Self.buildView(element: resultElement, context: context)
                        }
                    }
                }
                
                return AnyView(Text("Custom component function type error").background(Color.blue))
            }
        }
        return AnyView(Text("UnknownTagType").background(Color.purple))
    }
    
    static func unknownStringTagView(element: ScriptWidgetRuntimeElement, context: ScriptWidgetElementContext) -> AnyView {
        if let tag = element.tagAsString() {
            if tag == "Fragment" {
                return AnyView(Group(content: {
                    ForEach(element.childrenAsElements()) { item -> AnyView in
                        return ScriptWidgetElementView.buildView(element: item, context: context)
                    }
                }))
            }
        }
        
        return AnyView(Text("UnknownTagName").background(Color.pink))
    }
}

struct ScriptWidgetElementView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetElementView(
            element: ScriptWidgetRuntimeElement(tagString: "text", props: nil, children: ["Hello SwiftWidget"]),
            context: ScriptWidgetElementContext(runtime: nil,debugMode: true, scriptName: "", scriptParameter: "",package: globalScriptWidgetPackage)
        )
    }
}
