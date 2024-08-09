//
//  MacKitUtil.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/25.
//

import Foundation
import AppKit
import SwiftUI

public class MacKitUtil {
    
    public static func openUrl(_ strURL: String) {
        guard let url = URL(string: strURL) else { return }
        NSWorkspace.shared.open(url)
    }
    
    public static func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
    
    public static func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
    
    public static func selectDirectory(title: String, completion: @escaping (_ path: URL?) -> Void) {
        let dialog = NSOpenPanel();
        dialog.title = title;
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canChooseFiles = false;
        dialog.canChooseDirectories = true;
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            completion(dialog.url)
        } else {
            completion(nil)
        }
    }
    
    public static func selectFile(title: String, completion: @escaping (_ path: URL?) -> Void) {
        let dialog = NSOpenPanel();
        dialog.title = title;
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canChooseFiles = true;
        dialog.canChooseDirectories = false;
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            completion(dialog.url)
        } else {
            completion(nil)
        }
    }
    
    public static func alertInfo(title: String, message: String) {
        guard let window = NSApp.keyWindow else {
            return
        }
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "OK")
        a.alertStyle = .informational
        a.beginSheetModal(for: window) { resp in
            print("alert result : \(resp)")
        }
    }
    
    
    public static func alertWarn(title: String, message: String) {
        guard let window = NSApp.keyWindow else {
            return
        }
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: "OK")
        a.alertStyle = .warning
        a.beginSheetModal(for: window) { resp in
            print("alert result : \(resp)")
        }
    }
    
    public static func isSystemThemeDark() -> Bool {
        return NSApp.effectiveAppearance.name == NSAppearance.Name.darkAqua
    }
    
    public static func inputBox(title: String, message: String, placeholder: String, completionHandler: @escaping (_ inputText: String) -> Void) {
        guard let window = NSApp.keyWindow else {
            return
        }
        let a = NSAlert()
        a.messageText = title
        if !message.isEmpty {
            a.informativeText = message
        }
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputTextField.placeholderString = placeholder
        a.accessoryView = inputTextField

        a.beginSheetModal(for: window) { resp in
            print("input result : \(resp)")
            if resp == .alertFirstButtonReturn {
                let inputText = inputTextField.stringValue
                print("input : \(inputText)")
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    completionHandler(inputText)
                } else {
                    print("empty after trim")
                }
            }
        }
    }
    
    
    public static func alertWarn(title: String, message: String, completionHandler: @escaping (_ isOK: Bool) -> Void) {
        guard let window = NSApp.keyWindow else {
            return
        }
        let a = NSAlert()
        a.messageText = title
        if !message.isEmpty {
            a.informativeText = message
        }
        a.addButton(withTitle: "OK")
        a.addButton(withTitle: "Cancel")
        a.alertStyle = .warning
        a.beginSheetModal(for: window) { resp in
            print("alert result : \(resp)")
            if resp == .alertFirstButtonReturn {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
    
    public static func saveImage(_ image: NSImage, atUrl url: URL) {
        guard
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { return } 
        let newRep = NSBitmapImageRep(cgImage: cgImage)
        newRep.size = image.size // if you want the same size
        guard
            let pngData = newRep.representation(using: .png, properties: [:])
            else { return } // TODO: handle error
        do {
            try pngData.write(to: url)
        }
        catch {
            print("error saving: \(error)")
        }
    }
}

extension View {
    func snapshot() -> NSImage? {
        let controller = NSHostingController(rootView: self)
        let targetSize = controller.view.intrinsicContentSize
        let contentRect = NSRect(origin: .zero, size: targetSize)
        
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = controller.view
        
        guard
            let bitmapRep = controller.view.bitmapImageRepForCachingDisplay(in: contentRect)
        else { return nil }
        
        controller.view.cacheDisplay(in: contentRect, to: bitmapRep)
        let image = NSImage(size: bitmapRep.size)
        image.addRepresentation(bitmapRep)
        return image
    }
}
