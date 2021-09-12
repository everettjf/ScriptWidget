//
//  ScriptModel.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import SwiftUI

struct ScriptModel : Identifiable {
    let id = UUID()
    let name: String
    let file: ScriptWidgetFile
}


let globalScriptModel = ScriptModel(name: "Is Friday Today", file: ScriptWidgetFile(bundle: "Script", relativePath: "template/Is Friday Today.jsx"))
