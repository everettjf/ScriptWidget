//
//  ScriptManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/10.
//

import Foundation
import SwiftUI
import SwiftyJSON



class ScriptManager {
    
    let scriptDirectory: URL
    let isUsingiCloud: Bool
    
    init() {
        var root = URL(fileURLWithPath: "")
        if let url = ScriptManager.getICloudRootDirectoryURL() {
            root = url
            isUsingiCloud = true
        } else {
            root = ScriptManager.getSandboxRootDirectoryURL()!
            isUsingiCloud = false
        }

        print("root = \(String(describing: root))")
        
        self.scriptDirectory = root.appendingPathComponent("Scripts")
        
        try? FileManager.default.createDirectory(at: self.scriptDirectory, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.protectionKey : FileProtectionType.none
        ])
    }
    
    static func getICloudRootDirectoryURL() -> URL? {
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return url.appendingPathComponent("Documents")
        }
        return nil
    }
    
    static func getSandboxRootDirectoryURL() -> URL? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget") {
            return url.appendingPathComponent("Documents")
        }
        return nil
    }
    
    static func getSandboxFileCount() -> Int {
        if let url = ScriptManager.getSandboxRootDirectoryURL() {
            let items = try? FileManager.default.contentsOfDirectory(atPath: url.path)
            return items?.count ?? 0
        }
        return 0
    }
    
    static func moveSandboxFilesToICloud() -> Bool {
        guard let icloudUrl = ScriptManager.getICloudRootDirectoryURL() else { return false }
        guard let sandboxUrl = ScriptManager.getSandboxRootDirectoryURL() else { return false }
        
        var errorOccur = false
        guard let sandboxItems = try? FileManager.default.contentsOfDirectory(atPath: sandboxUrl.path) else { return false }
        for item in sandboxItems {
            let srcRoot = sandboxUrl.appendingPathComponent(item)
            let destRoot = icloudUrl.appendingPathComponent(item)
            
            // make sure destRoot exist
            try? FileManager.default.createDirectory(at: destRoot, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.protectionKey : FileProtectionType.none
            ])
            
            // move each item in root
            if let files = try? FileManager.default.contentsOfDirectory(atPath: srcRoot.path) {
                
                for fileName in files {
                    let srcPath = srcRoot.appendingPathComponent(fileName)
                    var destPath = destRoot.appendingPathComponent(fileName)
                    
                    let fileExt = destPath.pathExtension
                    let fileNameNoExt = destPath.deletingPathExtension().lastPathComponent
                    
                    for index in 1...1000 {
                        if !FileManager.default.fileExists(atPath: destPath.path) {
                            break
                        }
                        destPath = destRoot.appendingPathComponent("\(fileNameNoExt) (\(index)).\(fileExt)")
                    }
                    
                    print("will move \(srcPath) to \(destPath)")
                    
                    do {
                        // make sure succeed
                        try FileManager.default.moveItem(at: srcPath, to: destPath)
                        
                        // succeed, delete src, ignore result
                        try? FileManager.default.removeItem(at: srcPath)
                        
                        print("move done")
                    } catch {
                        print("error occur = \(error)")
                        errorOccur = true
                    }
                }
            }
            
            if !errorOccur {
                // remove srcRoot
                try? FileManager.default.removeItem(at: srcRoot)
            }

        }
        
        return !errorOccur
    }
    
    func isICloudAvaliable() -> Bool {
        if let _ = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return true
        } else {
            return false
        }
    }
    
    func getScriptPath(scriptId: String) -> URL {
        return self.scriptDirectory.appendingPathComponent(scriptId).appendingPathExtension("jsx")
    }
    
    
    func saveScript(scriptId: String, content: String) -> Bool {
        let scriptPath = self.getScriptPath(scriptId: scriptId)
        let file = ScriptWidgetFile(fileURL: scriptPath)
        
        // file content
        if !file.writeFile(content: content) {
            return false
        }
        
        return true
    }
    
    func renameScript(srcScriptId: String, destScriptId: String) -> (Bool, String) {
        if srcScriptId == destScriptId {
            return (true, "No need rename")
        }
        
        let srcScriptPath = self.getScriptPath(scriptId: srcScriptId)
        let destScriptPath = self.getScriptPath(scriptId: destScriptId)
        
        let file = ScriptWidgetFile(fileURL: srcScriptPath)
        return file.rename(destURL: destScriptPath)
    }
    
    func createScript(content: String, recommendScriptId: String) -> Bool {
        
        // get valid id (name)
        var scriptId = recommendScriptId
        if self.isExist(scriptId: scriptId) {
            for index in 1...10000 {
                let newId = "\(recommendScriptId) (\(index))"
                if !self.isExist(scriptId: newId) {
                    scriptId = newId
                    break
                }
            }
        }
        
        return self.saveScript(scriptId: scriptId, content: content)
    }
    
    
    func isExist(scriptId: String) -> Bool {
        let path = self.getScriptPath(scriptId: scriptId)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    func scriptCount() -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: self.scriptDirectory.path) else { return 0 }
        var count = 0;
        for (_, item) in items.enumerated() {
            if !item.hasSuffix(".jsx") {
                continue
            }
            count += 1
        }
        return count
    }
    
    func listScripts() -> [ScriptModel] {
        
        var models = [ScriptModel]()
        
        // user created scripts
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: self.scriptDirectory.path) else { return [] }
        
        for (_, item) in items.enumerated() {
            if !item.hasSuffix(".jsx") {
                continue
            }
            
            let scriptPath = self.scriptDirectory.appendingPathComponent(item)
            
            var scriptId = item
            scriptId.removeLast(4)
            
            let file = ScriptWidgetFile(fileURL: scriptPath)
            
            models.append(ScriptModel(name: scriptId, file: file))
        }
        
        models.sort { (a, b) -> Bool in
            return a.name < b.name
        }
        
        
        return models
    }
    
    
    func getScript(scriptId: String) -> ScriptModel {
        let scriptFileName = "\(scriptId).jsx"
        let scriptPath = self.scriptDirectory.appendingPathComponent(scriptFileName)
        let file = ScriptWidgetFile(fileURL: scriptPath)
        return ScriptModel(name: scriptId, file: file)
    }
    
    
    func deleteScript(scriptId: String) -> Bool {
        
        let scriptFileName = "\(scriptId).jsx"
        let scriptPath = self.scriptDirectory.appendingPathComponent(scriptFileName)
        let file = ScriptWidgetFile(fileURL: scriptPath)
        
        return file.delete()
    }
    
    
}
let sharedScriptManager = ScriptManager()
