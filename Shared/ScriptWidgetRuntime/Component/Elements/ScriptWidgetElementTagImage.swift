//
//  ScriptWidgetElementTagImage.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/11/2.
//

import Foundation
import SwiftUI


struct FileSyncImage: View {
    let fileUrl: URL
    private var fileImage: UIImage?
    
    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        if let fileData = try? Data(contentsOf: self.fileUrl) {
            self.fileImage = UIImage(data: fileData)
        }
    }
    
    var body: some View {
        if let fileImage = self.fileImage {
            Image(uiImage: fileImage)
                .resizable()
        } else {
            Image(systemName: "questionmark.circle")
        }
    }
}



struct WebSyncImage: View {
    let webUrl: URL
    private var image: UIImage?
    
    init(webUrl: URL) {
        self.webUrl = webUrl
        
        do {
            let fileData = try Data(contentsOf: self.webUrl)
            self.image = UIImage(data: fileData)
        } catch {
            print("web sync image error : \(error)")
        }
    }
    var body: some View {
        if let image = self.image {
            Image(uiImage: image)
                .resizable()
        } else {
            Image(systemName: "questionmark.circle")
        }
    }
}



class ScriptWidgetElementTagImage {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        
        // systemName : SF Symbols
        if let systemName = element.getPropString("systemName") {
            return AnyView(
                Image(systemName: systemName)
                    .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
            )
        }
        
        // id
        if let imageId = element.getPropString("id") {
            let imagePath = sharedImageManager.getImagePath(imageId: imageId)
            return AnyView(
                FileSyncImage(fileUrl: imagePath)
                    .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
            )
        }
        
        // url
        if let imageUrlString = element.getPropString("url") {
            if let imageUrl = URL(string: imageUrlString) {
                return AnyView(
                    WebSyncImage(webUrl: imageUrl)
                        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
                )
            }
        }
        
        // default
        return AnyView(
            Image(systemName: "questionmark.circle")
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}
