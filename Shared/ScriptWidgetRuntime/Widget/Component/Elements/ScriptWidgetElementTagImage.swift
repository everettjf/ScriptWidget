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
#if os(macOS)
    private var fileImage: NSImage?
#else
    private var fileImage: UIImage?
#endif
    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        if let fileData = try? Data(contentsOf: self.fileUrl) {
#if os(macOS)
            self.fileImage = NSImage(data: fileData)
#else
            self.fileImage = UIImage(data: fileData)
#endif
        }
    }
    
    var body: some View {
        if let fileImage = self.fileImage {
#if os(macOS)
            Image(nsImage: fileImage)
                .resizable()
#else
            Image(uiImage: fileImage)
                .resizable()
#endif
        } else {
            Image(systemName: "questionmark.circle")
        }
    }
}



struct WebSyncImage: View {
    let webUrl: URL
#if os(macOS)
    private var image: NSImage?
#else
    private var image: UIImage?
#endif
    
    init(webUrl: URL) {
        self.webUrl = webUrl
        
        do {
            let fileData = try Data(contentsOf: self.webUrl)
#if os(macOS)
            self.image = NSImage(data: fileData)
#else
            self.image = UIImage(data: fileData)
#endif
        } catch {
            print("web sync image error : \(error)")
        }
    }
    var body: some View {
        if let image = self.image {
#if os(macOS)
            Image(nsImage: image)
                .resizable()
#else
            Image(uiImage: image)
                .resizable()
#endif
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
                    .modifier(ScriptWidgetAttributeImageModifier(element, context))
                    .modifier(ScriptWidgetAttributeFontModifier(element))
                    .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
            )
        }
        
        // name or id
        if let imageName = element.getPropString("name", or: "id") {
            // first try local image
            if let image = context.package.getImage(imageName) {
                return AnyView(
                    FileSyncImage(fileUrl: image.path)
                        .modifier(ScriptWidgetAttributeImageModifier(element, context))
                        .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
                )
            }
        }
        
        // url or src
        if let imageUrlString = element.getPropString("url", or: "src") {
            /*
             <image
             url="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4
             //8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg=="
             />
             
             supports:
             data:image/jpeg;base64,
             data:image/png;base64,
             */
            let base64imagePngPrefix = "data:image/png;base64,"
            let base64imageJpegPrefix = "data:image/jpeg;base64,"
            if imageUrlString.starts(with: base64imagePngPrefix) {
                // image base64 url
                let prefixIndex = imageUrlString.index(imageUrlString.startIndex, offsetBy: base64imagePngPrefix.count)
                let base64String = String(imageUrlString.suffix(from: prefixIndex))
                if let base64Data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
#if os(macOS)
                    if let image = NSImage(data: base64Data){
                        return AnyView(Image(nsImage: image)
                            .modifier(ScriptWidgetAttributeImageModifier(element, context))
                            .modifier(ScriptWidgetAttributeGeneralModifier(element, context)))
                    }
#else
                    if let image = UIImage(data: base64Data){
                        return AnyView(Image(uiImage: image)
                            .modifier(ScriptWidgetAttributeImageModifier(element, context))
                            .modifier(ScriptWidgetAttributeGeneralModifier(element, context)))
                    }
#endif
                }
            } else if imageUrlString.starts(with: base64imageJpegPrefix) {
                // image base64 url
                let prefixIndex = imageUrlString.index(imageUrlString.startIndex, offsetBy: base64imageJpegPrefix.count)
                let base64String = String(imageUrlString.suffix(from: prefixIndex))
                if let base64Data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
#if os(macOS)
                    if let image = NSImage(data: base64Data){
                        return AnyView(Image(nsImage: image)
                            .modifier(ScriptWidgetAttributeImageModifier(element, context))
                            .modifier(ScriptWidgetAttributeGeneralModifier(element, context)))
                    }
#else
                    if let image = UIImage(data: base64Data){
                        return AnyView(Image(uiImage: image)
                            .modifier(ScriptWidgetAttributeImageModifier(element, context))
                            .modifier(ScriptWidgetAttributeGeneralModifier(element, context)))
                    }
#endif
                }
            } else {
                // normal url
                if let imageUrl = URL(string: imageUrlString) {
                    return AnyView(
                        WebSyncImage(webUrl: imageUrl)
                            .modifier(ScriptWidgetAttributeImageModifier(element, context))
                            .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
                    )
                }
            }
        }
        
        // default
        return AnyView(
            Image(systemName: "questionmark.circle")
                .modifier(ScriptWidgetAttributeImageModifier(element, context))
                .modifier(ScriptWidgetAttributeFontModifier(element))
                .modifier(ScriptWidgetAttributeGeneralModifier(element, context))
        )
    }
}
