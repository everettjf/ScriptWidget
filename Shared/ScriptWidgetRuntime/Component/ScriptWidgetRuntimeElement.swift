//
//  SwiftWidgetRuntimeElement.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/15.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeElementExports: JSExport {
    var tag: String { get set }
    var props: [AnyHashable:Any]? { get set }
    var children: [Any]? { get set }
    
    static func createElement(_ tag: String, _ props: [AnyHashable:Any]?, _ children: [Any]? ) -> ScriptWidgetRuntimeElement

}

@objc public class ScriptWidgetRuntimeElement: NSObject, ScriptWidgetRuntimeElementExports, Identifiable {
    dynamic var tag: String
    dynamic var props: [AnyHashable:Any]?
    dynamic var children: [Any]?
    var depth = 0
    
    public let id = UUID()

    required init(tag: String, props: [AnyHashable:Any]?, children: [Any]?) {
        self.tag = tag
        self.props = props
        self.children = children
    }
    
    public func getPropString(_ key: String) -> String? {
        guard let props = self.props else { return nil }
        guard let value = props[key] as? String else { return nil }
        return value
    }
    
    public func getPropInt(_ key: String) -> Int? {
        guard let props = self.props else { return nil }
        if let value = props[key] as? Int { return value }
        
        if let value = props[key] as? String {
            if let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }
    
    public func getPropDouble(_ key: String) -> Double? {
        guard let props = self.props else { return nil }
        if let value = props[key] as? Double { return value }
        if let value = props[key] as? String {
            if let doubleValue = Double(value) {
                return doubleValue
            }
        }
        return nil
    }
    
    class func createElement(_ tag: String, _ props: [AnyHashable:Any]?, _ children: [Any]? ) -> ScriptWidgetRuntimeElement {
        return ScriptWidgetRuntimeElement(tag: tag, props: props, children: children)
    }
    
    public override var description: String {
        var indent = ""
        for _ in 0..<depth {
            indent += "    "
        }
        
        var desc = """
        \(indent)+ScriptWidgetRuntimeElement
        \(indent)  |tag: \(tag)
        \(indent)  |props: \(String(describing: props))
        """
        desc += "\n"
        
        if let children = self.children {
            if children.count == 0 {
                desc += "\(indent)  |children: None\n"
            } else {
                desc += "\(indent)  |children:\n"
                
                let childDepth = depth + 1
                for child in children {
                    var childIndent = ""
                    for _ in 0..<childDepth {
                        childIndent += "    "
                    }
                    
                    switch child {
                    case let child as ScriptWidgetRuntimeElement:
                        child.depth = childDepth
                        desc += "\(child)\n"
                    case let child as String:
                        desc += "\(childIndent)  String: \(child)\n"
                    case let child as NSNumber:
                        desc += "\(childIndent)  Number: \(child)\n"
                    default:
                        desc += "\(childIndent)  Unknown: \(type(of: child)) = \(child)\n"
                    }
                }
            }
        } else {
            desc += "\(indent)  |children: None\n"
        }
        
        return desc;
    }
}
