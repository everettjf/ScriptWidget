//
//  ScriptPackageHorizontalFileView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/9/10.
//

import SwiftUI

struct ScriptPackageFileItemView : View {
    let name: String
    let highlight: Bool
    let onTapped: () -> Void
    
    var body: some View {
        Button {
            onTapped()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "doc")
                Text(name)
            }
            .font(highlight ? .caption : .caption2)
            .fontWeight(highlight ? .bold : .regular)
        }
        .buttonStyle(.bordered)
        .padding(.all, 0)
    }
}

class ScriptPackageHorizontalFileStateObject : ObservableObject {
    let model: ScriptModel
    let highlightName: String
    @Published var files : [FileModel]
    
    init(model: ScriptModel, currentFilePath: URL) {
        self.model = model
        self.files = model.package.listRootFiles()
        self.highlightName = currentFilePath.lastPathComponent
    }
}

struct ScriptPackageHorizontalFileView: View {
    @ObservedObject var state: ScriptPackageHorizontalFileStateObject
    let onFileChanged: (_ file: FileModel) -> Void
    
    init(model: ScriptModel, currentFilePath: URL, onFileChanged: @escaping (_: FileModel) -> Void) {
        self.state = ScriptPackageHorizontalFileStateObject(model: model, currentFilePath: currentFilePath)
        self.onFileChanged = onFileChanged
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 2) {
                ForEach(state.files) { file in
                    ScriptPackageFileItemView(name: file.name, highlight: state.highlightName == file.name) {
                        onFileChanged(file)
                    }
                }
                Spacer()
            }
        }
    }
}

struct ScriptPackageHorizontalFileView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptPackageHorizontalFileView(model: globalScriptModel, currentFilePath: globalScriptModel.package.jsxPath) { file in
        }
        ScriptPackageHorizontalFileView(model: globalScriptModel, currentFilePath: URL(string: "/Users/preview.jsx")!) { file in
        }
    }
}
