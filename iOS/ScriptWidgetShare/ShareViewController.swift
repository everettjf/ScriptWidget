//
//  ShareViewController.swift
//  ScriptWidgetShare
//
//  Created by everettjf on 2021/3/16.
//

import UIKit
import UniformTypeIdentifiers


class ShareViewController: UIViewController {
    private let typeURL = UTType.url.identifier
    
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
        
        if itemProvider.hasItemConformingToTypeIdentifier(typeURL) {
            itemProvider.loadItem(forTypeIdentifier: typeURL, options: nil) { (item, error) in
                if let error = error {
                    print("URL-Error: \(error.localizedDescription)")
                }

                if let url = item as? NSURL {
                    self.importFileWithURL(fileURL: url as URL)
                }

                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
            return
        }

        // Files shared from a web page (Web Share API in Safari) arrive as a
        // file representation typed by MIME, not as a URL.
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            let suggestedName = itemProvider.suggestedName
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { (url, error) in
                if let error = error {
                    print("File-Error: \(error.localizedDescription)")
                }

                // The representation is only valid inside this handler.
                if let url = url {
                    self.importSharedFile(at: url, suggestedName: suggestedName)
                }

                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
            return
        }

        print("Error: No url or file found")
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    /// Copies a shared file under its suggested name so the extension decides
    /// the import format, then imports it.
    private func importSharedFile(at url: URL, suggestedName: String?) {
        var fileName = url.lastPathComponent
        if let suggestedName = suggestedName, !suggestedName.isEmpty {
            let safeName = (suggestedName as NSString).lastPathComponent
            fileName = (safeName as NSString).pathExtension.isEmpty ? "\(safeName).\(url.pathExtension)" : safeName
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let copy = directory.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: url, to: copy)
            importFileWithURL(fileURL: copy)
        } catch {
            print("copy shared file failed : \(error)")
        }
    }
    
    
    private func importFileWithURL(fileURL: URL) {
        print(fileURL)
        
        let fileExt = fileURL.pathExtension.lowercased()
        switch fileExt {
        case "jsx": importJSXFile(fileURL: fileURL)
        case "swt": importSWTFile(fileURL: fileURL)
        default: print("un support file format")
        }
    }
    
    private func importSWTFile(fileURL: URL) {
        
        let result = sharedScriptManager.importScript(fromPath: fileURL)
        if result {
            print("import swt succeed")
            
            self.openAppAfterImported()

        } else {
            print("import swt failed")
        }
    }
    
    private func importJSXFile(fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        let fileNameWithoutExt = fileURL.deletingPathExtension().lastPathComponent
        
        print("fileName = \(fileName)")
        print("fileNameWithoutExt = \(fileNameWithoutExt)")

        // save to icloud or sandbox
        let targetPackageName = fileNameWithoutExt
        
        do {
            let fileContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            let result = sharedScriptManager.createScript(content: fileContent, recommendPackageName: targetPackageName, imageCopyPath: nil)
            if result.0 {
                print("succeed import")
                
                self.openAppAfterImported()

            } else {
                print("save script failed : \(result.1)")
            }
        
        } catch {
            print("read file failed : \(error)")
        }
    }
    
    private func openAppAfterImported() {
        
        if let appurl = URL(string: "scriptwidget://") {
            self.openURL(appurl)
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
