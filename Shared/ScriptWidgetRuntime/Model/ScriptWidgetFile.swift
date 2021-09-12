//
//  ScriptWidgetFile.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import Foundation
import SwiftyJSON


struct ScriptWidgetFile {
    let fileURL: URL
    let fileName: String
    let isBundle: Bool
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        self.isBundle = false
        self.fileName = fileURL.lastPathComponent
    }
    
    init(bundle: String, relativePath: String) {
        let bundleURL = Bundle.main.url(forResource: bundle, withExtension: "bundle")
        self.fileURL = bundleURL!.appendingPathComponent(relativePath)
        self.isBundle = true
        self.fileName = self.fileURL.lastPathComponent
    }
    
    func fileNameWithoutExtension() -> String {
        return "\(String(fileName.split(separator: ".").first ?? "-"))"
    }
    
    func readFile() -> String? {
        return try? String(contentsOf: self.fileURL)
    }
    
    func writeFile(content: String) -> Bool {
        if self.isBundle { return false }
        
        guard let data = content.data(using: .utf8) else { return false }
        do {
            try data.write(to: self.fileURL)
            
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: self.fileURL.path)

        } catch {
            return false
        }
        return true
    }
    
    
    func rename(destURL: URL) -> (Bool, String) {
        if self.isBundle { return (false, "Bundle file not movable")}
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            return (false, "New file name already exists")
        }
        
        do {
            try FileManager.default.moveItem(at: self.fileURL, to: destURL)
        } catch {
            return (false, "\(error)")
        }
        return (true, "")
    }
    
    func delete() -> Bool {
        do {
            try FileManager.default.removeItem(at: self.fileURL)
        } catch {
            return false
        }
        return true
    }
    
}


let globalScriptWidgetFile = ScriptWidgetFile(bundle: "Script", relativePath: "template/Is Friday Today.jsx")
