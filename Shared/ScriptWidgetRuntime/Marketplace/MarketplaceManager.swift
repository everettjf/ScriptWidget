//
//  MarketplaceManager.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/2/9.
//

import Foundation
import SwiftUI

struct MarketplaceJSONHomeWidgetModel: Codable {
    let name: String
    let size: String
}
struct MarketplaceJSONHomeModel: Codable {
    let name: String
    let maintainer: String
    let widgets: [MarketplaceJSONHomeWidgetModel]
}
struct MarketplaceJSONPackageModel : Codable {
    let description: String
    let author: String
    let snapshots: [String]
    let files: [String]
}

struct MarketplaceWidgetModel: Identifiable {
    let id = UUID()
    let name: String
    let size: String
    let package: MarketplaceJSONPackageModel
    
    func getImageURL() -> URL? {
        guard let firstSnapshot = package.snapshots.first else {
            return nil
        }
        
        guard let encodeName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return nil
        }
        let url = "https://scriptwidget.app/marketplace/widgets/\(encodeName)/\(firstSnapshot)"
        print("image url = \(url)")
        return URL(string: url)
    }
    
    func snapshotsURLs() -> [URL] {
        var urls = [URL]()
        for snapshot in package.snapshots {
            if let encodeName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                if let url = URL(string: "https://scriptwidget.app/marketplace/widgets/\(encodeName)/\(snapshot)") {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    func previewSize() -> CGSize {
        if size == "small" {
            return .init(width: 149, height: 149)
        } else if size == "medium" {
            return .init(width: 330, height: 149)
        } else if size == "large" {
            return .init(width: 300, height: 316)
        } else {
            return .init(width: 149, height: 149)
        }
    }
    
    func getFileURLs() -> [(String, URL)] {
        guard let encodeName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return []
        }
        
        var items = [(String, URL)]()
        for file in package.files {
            if let url = URL(string: "https://scriptwidget.app/marketplace/widgets/\(encodeName)/\(file)") {
                items.append((file, url))
            }
        }
        return items
    }
}

class MarketplaceManager {
    static func fetchHomeModel() async -> MarketplaceJSONHomeModel? {
        guard let url = URL(string: "https://scriptwidget.app/marketplace/marketplace.json") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let homeModel = try JSONDecoder().decode(MarketplaceJSONHomeModel.self, from: data)
            
            print("home model : name = \(homeModel.name)")
            print("home model : maintainer = \(homeModel.maintainer)")
            print("home model : widget count = \(homeModel.widgets.count)")
            
            return homeModel
        } catch {
            debugPrint("Error loading \(url): \(String(describing: error))")
        }
        
        return nil
    }
    
    
    static func fetchPackageInfo(name: String) async -> MarketplaceJSONPackageModel? {
        
        guard let encodeName = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return nil
        }
        guard let url = URL(string: "https://scriptwidget.app/marketplace/widgets/\(encodeName)/package.json") else {
            return nil
        }
        do {
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let packageModel = try JSONDecoder().decode(MarketplaceJSONPackageModel.self, from: data)
            return packageModel
        } catch {
            debugPrint("Error fetch package info \(url): \(String(describing: error))")
        }
        return nil
    }
}

extension ScriptManager {
    
    func downloadPackage(model: MarketplaceWidgetModel, progress: (_ current: Int, _ total: Int) -> Void) async -> (Bool, String) {
        
        // get valid id (name)
        let packageName = self.getValidPackageName(recommendPackageName: model.name)
        let packagePath = self.getPackagePathFromPackageName(packageName: packageName)

        let packageFiles = model.getFileURLs()
        var failedDownload = false
        let total = packageFiles.count
        
        var index = 0
        var errorInfo = ""
        for packageFile in packageFiles {
            index += 1
            progress(index, total)
            
            let fileRelativeName = packageFile.0
            let fileURL = packageFile.1
            
            let fileSavePath = packagePath.appendingPathComponent(fileRelativeName)
            let fileSaveDir = fileSavePath.deletingLastPathComponent()
            
            // download
            do {
                let (data, _) = try await URLSession.shared.data(from: fileURL)
                
                // make sure dir exist
                if !FileManager.default.fileExists(atPath: fileSaveDir.path) {
                    try FileManager.default.createDirectory(at: fileSaveDir, withIntermediateDirectories: true, attributes: [
                        FileAttributeKey.protectionKey : FileProtectionType.none
                    ])
                }
                
                try data.write(to: fileSavePath)
                
            } catch {
                debugPrint("Error save \(fileURL) to \(fileSavePath) , error = \(String(describing: error))")
                errorInfo.append("Error save \(fileURL) to \(fileSavePath) , error = \(String(describing: error))\n")
                failedDownload = true
                break
            }
        }
        
        if failedDownload {
            try? FileManager.default.removeItem(at: packagePath)
        }
        
        return (!failedDownload, errorInfo)
    }
    
}

@MainActor class MarketplaceHomeDataObject: ObservableObject {
    @Published var smallWidgets = [MarketplaceWidgetModel]()
    @Published var mediumWidgets = [MarketplaceWidgetModel]()
    @Published var largeWidgets = [MarketplaceWidgetModel]()
    
    
    func reload() async {
        guard let homeModel = await MarketplaceManager.fetchHomeModel() else {
            return
        }
        
        print("home model : name = \(homeModel.name)")
        print("home model : maintainer = \(homeModel.maintainer)")
        print("home model : widget count = \(homeModel.widgets.count)")
        
        var smallWidgets = [MarketplaceWidgetModel]()
        var mediumWidgets = [MarketplaceWidgetModel]()
        var largeWidgets = [MarketplaceWidgetModel]()
        for widget in homeModel.widgets {
            print("current > \(widget.name)")
            if widget.size.isEmpty {
                continue
            }
            
            guard let packageInfo = await MarketplaceManager.fetchPackageInfo(name: widget.name) else {
                continue
            }
            
            let model = MarketplaceWidgetModel(
                name: widget.name,
                size: widget.size,
                package: packageInfo
            )
            
            let maxHomeCount = 10
            if widget.size == "large" {
                if largeWidgets.count < maxHomeCount {
                    largeWidgets.append(model)
                }
            } else if widget.size == "medium" {
                if mediumWidgets.count < maxHomeCount {
                    mediumWidgets.append(model)
                }
            } else if widget.size == "small" {
                if smallWidgets.count < maxHomeCount {
                    smallWidgets.append(model)
                }
            } else {
                // ignore
            }
        }
        
        self.smallWidgets = smallWidgets
        self.mediumWidgets = mediumWidgets
        self.largeWidgets = largeWidgets
    }
    
}

@MainActor class MarketplaceListDataObject: ObservableObject {
    @Published var widgets = [MarketplaceWidgetModel]()
    
    func reload(widgetSize: String) async {
        guard let homeModel = await MarketplaceManager.fetchHomeModel() else {
            return
        }
            
        print("home model : name = \(homeModel.name)")
        print("home model : maintainer = \(homeModel.maintainer)")
        print("home model : widget count = \(homeModel.widgets.count)")
        
        var widgets = [MarketplaceWidgetModel]()
        for widget in homeModel.widgets {
            print("current > \(widget.name)")
            if widget.size.isEmpty {
                continue
            }
            
            if widget.size != widgetSize {
                continue
            }
            
            guard let packageInfo = await MarketplaceManager.fetchPackageInfo(name: widget.name) else {
                continue
            }
            
            let model = MarketplaceWidgetModel(
                name: widget.name,
                size: widget.size,
                package: packageInfo
            )
            widgets.append(model)
        }
        
        self.widgets = widgets
    }
    
}
