//
//  FileListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/2/12.
//

import SwiftUI


class FileListDataObject: ObservableObject {
    @Published var files: [FileModel] = []
    
    let model: ScriptModel
    init(model: ScriptModel) {
        self.model = model
        
        self.reload()
    }
    
    func reload() {
        model.package.updateFiles()
        self.files = model.package.listFiles()
    }
}


struct FileListRowView: View {
    
    let scriptModel: ScriptModel
    let fileModel: FileModel
    
    var body: some View {
        NavigationLink(destination: FileDetailView(scriptModel: scriptModel, fileModel: fileModel)) {
            Text(fileModel.relativePath)
        }
    }
}

struct FileListView: View {
    @ObservedObject var data: FileListDataObject
    
    
    init(model: ScriptModel) {
        self.data = FileListDataObject(model: model)
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(data.files) { file in
                    FileListRowView(
                        scriptModel: data.model,
                        fileModel: file
                    )
                }
            }
        }
        .onAppear(perform: {
            self.data.reload()
        })
        .navigationBarTitle(Text(LocalizedStringKey("Files")), displayMode: .inline)
        .navigationBarItems(trailing: HStack {
            NavigationLink(destination: FileCreateView(scriptModel: data.model)) {
                Image(systemName: "plus")
            }
        })
    }
}

struct FileListView_Previews: PreviewProvider {
    static var previews: some View {
        FileListView(model: globalScriptModel)
    }
}
