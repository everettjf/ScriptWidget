//
//  ScriptModel.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import SwiftUI

struct ScriptModel : Identifiable {
    
    let id = UUID()
    let package: ScriptWidgetPackage
    
    init(package: ScriptWidgetPackage) {
        self.package = package
    }
    
    var name: String {
        get {
            self.package.name
        }
    }
    
    var exportFileName: String {
        get {
            "\(self.package.name).swt"
        }
    }
}




let globalScriptModel = ScriptModel(package: ScriptWidgetPackage(bundle: "Script", relativePath: "template/Is Friday Today"))
let globalFileModel = FileModel(name: "config.json", relativePath: "config.json", path: URL(fileURLWithPath: "config.json"))
