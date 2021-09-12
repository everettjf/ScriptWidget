//
//  ShareViewController.swift
//  ScriptWidgetShare
//
//  Created by everettjf on 2021/3/16.
//

import UIKit
import CoreServices


class ShareViewController: UIViewController {
    private let typeURL = String(kUTTypeURL)

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        processShareInfo()
    }
    
    private func processShareInfo() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        if !itemProvider.hasItemConformingToTypeIdentifier(typeURL) {
            print("Error: No url or text found")
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        handleIncomingURL(itemProvider: itemProvider)
    }
    
    private func handleIncomingURL(itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: typeURL, options: nil) { (item, error) in
            if let error = error {
                print("URL-Error: \(error.localizedDescription)")
            }

            if let url = item as? NSURL {
                self.saveFileWithURL(fileURL: url as URL)
            }

            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    
    private func saveFileWithURL(fileURL: URL) {
        print(fileURL)
        
        let fileExt = fileURL.pathExtension
        if fileExt.lowercased() != "jsx" {
            return
        }
        
        let fileName = fileURL.lastPathComponent
        let fileNameWithoutExt = fileURL.deletingPathExtension().lastPathComponent
        
        print("fileName = \(fileName)")
        print("fileNameWithoutExt = \(fileNameWithoutExt)")

        // save to icloud or sandbox
        let targetScriptId = fileNameWithoutExt
        
        do {
            let fileContent = try String(contentsOf: fileURL)
            
            if sharedScriptManager.createScript(content: fileContent, recommendScriptId: targetScriptId) {
                print("succeed import")
                
                // mark update notification
                if let userDefaults = UserDefaults(suiteName: "group.everettjf.scriptwidget") {
                    userDefaults.set("share", forKey: "need_update_list")
                }
                
                if let appurl = URL(string: "scriptwidget://") {
                    self.openURL(appurl)
                }

            } else {
                print("save script failed")
            }
        
        } catch {
            print("read file failed : \(error)")
        }

    }
    
    //  Function must be named exactly like this so a selector can be found by the compiler!
    //  Anyway - it's another selector in another instance that would be "performed" instead.
    @discardableResult
    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                return application.perform(#selector(openURL(_:)), with: url) != nil
            }
            responder = responder?.next
        }
        return false
    }
}
