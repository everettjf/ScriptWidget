//
//  ImageManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/10.
//

import Foundation
import UIKit
import SwiftUI
import SwiftyJSON

struct ImageModel : Identifiable {
    let id = UUID()
    let imageId: String
    let widgetSizeType: Int
    let filePath: URL
}


class ImageManager {
    
    let imageDirectory: URL
    let isUsingiCloud: Bool


    init() {
        var root = URL(fileURLWithPath: "")
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            root = url.appendingPathComponent("Documents")
            isUsingiCloud = true
        } else {
            root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget")!
            isUsingiCloud = false
        }
        
        print("root = \(String(describing: root))")
        
        self.imageDirectory = root.appendingPathComponent("Images")
        
        try? FileManager.default.createDirectory(at: self.imageDirectory, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.protectionKey : FileProtectionType.none
        ])
    }
    
    func getImagePath(imageId: String) -> URL {
        return self.imageDirectory.appendingPathComponent(imageId).appendingPathExtension("png")
    }
    
    func getImagePropertyPath(imageId: String) -> URL {
        let imagePath = getImagePath(imageId: imageId)
        return imagePath.deletingPathExtension().appendingPathExtension("json")
    }
    
    // now , name is almost equal to id
    func saveImage(image: UIImage, imageId: String, widgetSizeType: Int) -> Bool {
        
        // write image
        let imagePath = self.getImagePath(imageId: imageId)
        do {
            guard let imageData = image.pngData() else { return false }
            try imageData.write(to: imagePath)
            
            try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: imagePath.path)
        } catch {
            print("save image \(error)")
            return false
        }
        
        let propPath = self.getImagePropertyPath(imageId: imageId)
        do {
            // write image prop
            let json = JSON([
                "widget-size-type": widgetSizeType
            ])
            
            if let jsonContent = json.rawString() {
                if let jsonData = jsonContent.data(using: .utf8) {
                    try jsonData.write(to: propPath)
                    
                    try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: propPath.path)
                }
            }
            
        } catch {
            print("save prop \(error)")
            
            // remove image to restore state
            try? FileManager.default.removeItem(at: imagePath)
        }
        
        return true
    }
    
    func getWidgetSizeTypeFromImageId(imageId: String) -> Int {
        let path = getImagePropertyPath(imageId: imageId)
        
        guard let content = try? String(contentsOf: path) else { return 0 }
        guard let data = content.data(using: .utf8, allowLossyConversion: false) else { return 0 }
        guard let json = try? JSON(data: data) else { return 0}
        
        let sizeType = json["widget-size-type"].intValue
        return sizeType
    }
    
    func imageCount() -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: self.imageDirectory.path) else { return 0 }
        
        var count = 0
        for item in items {
            if item.hasSuffix(".png") {
                count += 1
            }
        }
        return count
    }
    
    func listImages() -> (small:[ImageModel], medium:[ImageModel], large:[ImageModel]) {
        var small = [ImageModel]()
        var medium = [ImageModel]()
        var large = [ImageModel]()
        
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: self.imageDirectory.path) else { return (small,medium,large) }

        var models = [ImageModel]()
        for item in items {
            
            // only care image file
            if !item.hasSuffix(".png") {
                continue
            }
            
            let imagePath = self.imageDirectory.appendingPathComponent(item)
                        
            // image id
            var imageId = item
            imageId.removeLast(4)
            
            // widget size type
            let widgetSizeType = getWidgetSizeTypeFromImageId(imageId: imageId)
            
            models.append(ImageModel(imageId: imageId, widgetSizeType: widgetSizeType, filePath: imagePath))
        }
        
        
        models.sort { (a, b) -> Bool in
            if (a.widgetSizeType == b.widgetSizeType) {
                return a.filePath.lastPathComponent > b.filePath.lastPathComponent
            }
            return a.widgetSizeType < b.widgetSizeType
        }
        
        for model in models {
            if model.widgetSizeType == 0 {
                small.append(model)
            } else if model.widgetSizeType == 1 {
                medium.append(model)
            } else if model.widgetSizeType == 2 {
                large.append(model)
            } else {
                small.append(model)
            }
        }
        
        return (small,medium,large)
    }
    
    func rename(srcImageId: String, destImageId: String) -> (Bool, String) {
        if srcImageId == destImageId {
            return (true, "")
        }
        
        let srcImagePath = getImagePath(imageId: srcImageId)
        let srcPropPath = getImagePropertyPath(imageId: srcImageId)
        
        let destImagePath = getImagePath(imageId: destImageId)
        let destPropPath = getImagePropertyPath(imageId: destImageId)
        
        if FileManager.default.fileExists(atPath: destImagePath.path) {
            return (false, "Target file already exists")
        }
        
        do {
            try FileManager.default.moveItem(at: srcImagePath, to: destImagePath)
            
            try? FileManager.default.removeItem(at: destPropPath)
            try FileManager.default.moveItem(at: srcPropPath, to: destPropPath)
        } catch {
        }
        
        return (true, "")
    }
    
    func delete(imageId: String) -> Bool {
        let imagePath = getImagePath(imageId: imageId)
        let propPath = getImagePropertyPath(imageId: imageId)
        
        do {
            try FileManager.default.removeItem(at: imagePath)
            try? FileManager.default.removeItem(at: propPath)
        } catch {
            return false
        }
        return true
    }

    
}


let sharedImageManager = ImageManager()
