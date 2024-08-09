//
//  ScriptWidgetPackage.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageModel : Identifiable {
    let id = UUID()
    let name: String
    let path: URL
}

struct FileModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let relativePath: String
    let path: URL
}

struct ScriptWidgetPackage {
    let path: URL
    let name: String
    let jsxPath: URL
    let configPath: URL
    let imagePath: URL
    let readonly: Bool
    
    init(path: URL, readonly: Bool) {
        self.readonly = readonly
        self.path = path
        self.jsxPath = self.path.appendingPathComponent("main.jsx")
        self.configPath = self.path.appendingPathComponent("config.json")
        self.imagePath = self.path.appendingPathComponent("image")
        self.name = self.path.lastPathComponent
    }
    
    // readwrite
    init(path: URL) {
        self.init(path: path, readonly: false)
    }
    
    // readonly
    init(bundle: String, relativePath: String) {
        let bundleURL = Bundle.main.url(forResource: bundle, withExtension: "bundle")
        let dirPath = bundleURL!.appendingPathComponent(relativePath)
        self.init(path: dirPath, readonly: true)
    }
    
    func fileNameWithoutExtension() -> String {
        return self.name
    }
    
    func updateFiles() {
        updateDirectory(self.path)
    }
    
    func updateImages() {
        updateDirectory(self.imagePath)
    }
    
    func updateDirectory(_ dirPath: URL) {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: dirPath.path)
            for item in items {
                let path = self.path.appendingPathComponent(item)
                
                var isDir: ObjCBool = false
                if !FileManager.default.fileExists(atPath: path.path, isDirectory: &isDir) {
                    continue
                }
                
                if isDir.boolValue {
                    updateDirectory(path)
                } else {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: path)
                }
            }
        } catch {
            print("error : \(error)")
        }
    }
    
    func readMainFile() -> (String?, String) {
        return readFile(fullPath: self.jsxPath)
    }
    
    func readFile(relativePath: String) -> (String?, String) {
        // make sure icloud download status
        let filePath = self.path.appendingPathComponent(relativePath)
        return readFile(fullPath: filePath)
    }
    
    func readFile(fullPath: URL) -> (String?, String) {
        // make sure icloud download status
        do {
            if !FileManager.default.fileExists(atPath: fullPath.path) {
                print("file not exist now , try download from icloud : \(fullPath)")
                try? FileManager.default.startDownloadingUbiquitousItem(at: fullPath)
            }
            let values = try fullPath.resourceValues(forKeys: [.ubiquitousItemIsDownloadingKey])
            if values.ubiquitousItemDownloadRequested ?? false {
                print("requested download : \(fullPath)")
            }
            
            if values.ubiquitousItemIsDownloading ?? false {
                print("downloading : \(fullPath)")
            } else {
                //                print("not downloading : \(self.jsxPath)")
            }
            
            if values.ubiquitousItemDownloadingError != nil {
                print("download error : \(String(describing: values.ubiquitousItemDownloadingError))")
            }
            
        } catch {
            print("icloud start download exception : \(error)")
        }
        do {
            let content = try String(contentsOf: fullPath)
            return (content, "succeed")
        } catch {
            let errorInfo = "\(error)"
            return (nil, errorInfo)
        }
    }
    
    func makePackageDirectory() throws {
        try FileManager.default.createDirectory(at: self.path, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.protectionKey : FileProtectionType.none
        ])
    }
    
    func writeFile(fullPath: URL , content: String) -> (Bool, String) {
        if self.readonly { return (false, "Package is readonly") }
        
        guard let data = content.data(using: .utf8) else { return (false, "Failed to convert code to utf8 encoding") }
        do {
            if !FileManager.default.fileExists(atPath: fullPath.path) {
                try self.makePackageDirectory()
            }
            
            try data.write(to: fullPath)
            
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: fullPath.path)
            
        } catch {
            return (false, "Failed write code to path :\(fullPath) error: \(error)")
        }
        return (true, "")
    }
    
    func writeMainFile(content: String) -> (Bool,String) {
        return self.writeFile(fullPath: self.jsxPath, content: content)
    }
    
    func writeFile(relativePath: String, content: String) -> (Bool,String) {
        let fullPath = self.path.appendingPathComponent(relativePath)
        return self.writeFile(fullPath: fullPath, content: content)
    }
    
    func renameFile(relativePath: String, destRelativePath: String) -> (Bool, String) {
        let destFullPath = self.path.appendingPathComponent(destRelativePath)
        if FileManager.default.fileExists(atPath: destFullPath.path) {
            return (false, "new name existed")
        }
        let fullPath = self.path.appendingPathComponent(relativePath)
        do {
            try FileManager.default.moveItem(at: fullPath, to: destFullPath)
        } catch {
            return (false, "\(error)")
        }
        return (true, "")
    }
    
    func isFileExist(relativePath: String) -> Bool {
        let fullPath = self.path.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: fullPath.path)
    }
    
    func deleteFile(relativePath: String) {
        let fullPath = self.path.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: fullPath)
    }
    
    func rename(destPath: URL) -> (Bool, String) {
        if self.readonly { return (false, "Bundle file not movable")}
        
        if FileManager.default.fileExists(atPath: destPath.path) {
            return (false, "New package name already exists")
        }
        
        do {
            try FileManager.default.moveItem(at: self.path, to: destPath)
        } catch {
            return (false, "\(error)")
        }
        return (true, "")
    }
    
    func delete() -> Bool {
        do {
            try FileManager.default.removeItem(at: self.path)
        } catch {
            return false
        }
        return true
    }
    
    func getImage(_ imageName: String) -> ImageModel? {
        let imagePath = self.imagePath.appendingPathComponent(imageName).appendingPathExtension("png")
        if !FileManager.default.fileExists(atPath: imagePath.path) {
            return nil
        }
        return ImageModel(name: imageName, path: imagePath)
    }
    
    func getImageList() -> [ImageModel] {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: self.imagePath.path)
            var models = [ImageModel]()
            for item in items {
                let imagePath = self.imagePath.appendingPathComponent(item)
                let imageName = imagePath.deletingPathExtension().lastPathComponent
                models.append(ImageModel(name: imageName, path: imagePath))
            }
            models.sort { a, b in
                return a.name.compare(b.name) == .orderedAscending
            }
            return models
        } catch {
            print("get image list exception: \(error)")
        }
        return []
    }
    
#if os(macOS)
    func saveImage(imagePath: URL) -> Bool {
        try? FileManager.default.createDirectory(at: self.imagePath, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.none])
        
        if imagePath.pathExtension != "png" {
            return false
        }
        let fileName = imagePath.lastPathComponent
        var newFileName = fileName
        var newFilePath = self.imagePath.appendingPathComponent(newFileName)
        if FileManager.default.fileExists(atPath: newFilePath.path) {
            // file name existed, get a new name
            let count = self.getImageList().count
            newFileName = "image\(count).png"
            newFilePath = self.imagePath.appendingPathComponent(newFileName)
        }
        
        do {
            try FileManager.default.copyItem(at: imagePath, to: newFilePath)
        } catch {
            print("error = \(error)")
            return false
        }
        
        return true
    }
    func saveImage(image: NSImage, imageName: String) -> Bool {
        try? FileManager.default.createDirectory(at: self.imagePath, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.none])
        
        let imagePath = self.imagePath.appendingPathComponent(imageName).appendingPathExtension("png")
        do {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return false
            }
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            bitmap.size = image.size
            guard let imageData = bitmap.representation(using: .png, properties: [:]) else {
                return false
            }
            try imageData.write(to: imagePath)
            
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: imagePath.path)
        } catch {
            print("save image \(error)")
            return false
        }
        return true
    }
#else
    func saveImage(image: UIImage, imageName: String) -> Bool {
        try? FileManager.default.createDirectory(at: self.imagePath, withIntermediateDirectories: true, attributes: [FileAttributeKey.protectionKey: FileProtectionType.none])
        
        let imagePath = self.imagePath.appendingPathComponent(imageName).appendingPathExtension("png")
        do {
            guard let imageData = image.pngData() else { return false }
            try imageData.write(to: imagePath)
            
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: imagePath.path)
        } catch {
            print("save image \(error)")
            return false
        }
        return true
    }
#endif
    func renameImage(name: String, newName: String) -> (Bool, String) {
        let newPath = self.imagePath.appendingPathComponent("\(newName).png")
        if FileManager.default.fileExists(atPath: newPath.path) {
            return (false, "new name existed")
        }
        let oldPath = self.imagePath.appendingPathComponent("\(name).png")
        do {
            try FileManager.default.moveItem(at: oldPath, to: newPath)
            return (true, "succeed")
        } catch {
            return (false, "move failed : \(error)")
        }
    }
    
    
    func deleteImage(name: String) -> (Bool, String) {
        let path = self.imagePath.appendingPathComponent("\(name).png")
        do {
            try FileManager.default.removeItem(at: path)
            return (true, "succeed")
        } catch {
            return (false, "delete failed : \(error)")
        }
    }
    
    func listFiles() -> [FileModel] {
        return self.listFilesInternal()
    }
    
    private func listFilesInternal(_ leadingPath: String = "") -> [FileModel] {
        var curDir = self.path
        if !leadingPath.isEmpty {
            curDir = self.path.appendingPathComponent(leadingPath)
        }
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: curDir.path) else {
            return []
        }
        
        var items = [FileModel]()
        
        for file in files {
            let fullPath = curDir.appendingPathComponent(file)
            
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDir) {
                continue
            }
            
            if isDir.boolValue {
                var nextLeadingPath = ""
                if leadingPath.isEmpty {
                    nextLeadingPath = file
                } else {
                    nextLeadingPath = leadingPath + "/" + file
                }
                let innerFiles = self.listFilesInternal(nextLeadingPath)
                items.append(contentsOf: innerFiles)
            } else {
                if leadingPath.isEmpty {
                    items.append(FileModel(name: file, relativePath: file, path: fullPath))
                } else {
                    items.append(FileModel(name: file, relativePath: leadingPath + "/" + file, path: fullPath))
                }
            }
        }
        
        return items
    }
    
    func listRootFiles() -> [FileModel] {
        let curDir = self.path
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: curDir.path) else {
            return []
        }
        
        var items = [FileModel]()
        for file in files {
            let fullPath = curDir.appendingPathComponent(file)
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: fullPath.path, isDirectory: &isDir) {
                continue
            }
            if isDir.boolValue {
                continue
            }
            if file.suffix(4).lowercased() == ".jsx"
                || file.suffix(3).lowercased() == ".js"
                || file.suffix(5).lowercased() == ".json"
            {
                items.append(FileModel(name: file, relativePath: file, path: fullPath))
            }
        }
        
        return items.sorted { a, b in
            if a.name == "main.jsx" {
                return true
            }
            if b.name == "main.jsx" {
                return false
            }
            return a.name < b.name
        }
    }
}


let globalScriptWidgetPackage = ScriptWidgetPackage(bundle: "Script", relativePath: "template/Is Friday Today")
