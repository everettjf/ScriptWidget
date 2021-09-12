//
//  ScriptWidgetBundle.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import Foundation

struct ScriptWidgetBundle {
    let bundle: String
    
    func listScripts(relativePath: String) -> [ScriptModel] {
        
        var models = [ScriptModel]()
        
        guard let items = ScriptWidgetBundle.listBundleDirectory(bundle: bundle, relativePath: relativePath) else {
            return []
        }
        
        for (_, item) in items.enumerated() {
            if !item.hasSuffix(".jsx") {
                continue
            }
            
            var scriptId = item
            scriptId.removeLast(4)
            
            let file = ScriptWidgetFile(bundle: self.bundle, relativePath: "\(relativePath)/\(item)")
            
            models.append(ScriptModel(name: scriptId, file: file))
        }
        
        models.sort { (a, b) -> Bool in
            return a.name < b.name
        }
        
        
        return models
    }
    
    
    static func readFile(bundle: String, fileName: String) ->  String? {
        guard let bundleUrl = Bundle.main.url(forResource: bundle, withExtension: "bundle") else {
            return nil
        }
        guard let content = try? String(contentsOf: bundleUrl.appendingPathComponent(fileName)) else {
            return nil
        }
        return content
    }
    
    static func listBundleDirectory(bundle: String, relativePath: String) ->  [String]? {
        guard let bundleUrl = Bundle.main.url(forResource: bundle, withExtension: "bundle") else {
            return nil
        }
        let subDir = bundleUrl.appendingPathComponent(relativePath)
        
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: subDir.path) else {
            return nil;
        }
        return items
    }
}
