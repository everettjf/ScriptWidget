//
//  ScriptPackageEditorView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/10.
//

import SwiftUI

struct ScriptPackageEditorView: View {
    let model: ScriptModel
    @Binding var filePath: URL

    var body: some View {
        VStack {
            ScriptPackageHorizontalFileView(model: model, currentFilePath: filePath) { file in
                changeFile(fileModel: file)
            }
            MirrorEditorScriptView(model: model, filePath: filePath)
        }
    }
    
    
    func changeFile(fileModel: FileModel) {
        print("change file : \(fileModel.path.lastPathComponent)")
        self.filePath = fileModel.path
    }
}

struct ScriptPackageEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptPackageEditorView(model: globalScriptModel, filePath: .constant(URL(string: "/Users/main.jsx")!))
    }
}
