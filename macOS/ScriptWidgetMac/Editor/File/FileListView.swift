//
//  FileListView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/19.
//

import SwiftUI


class FileListDataObject: ObservableObject {
    @Published var files: [FileModel] = []
    
    let scriptModel: ScriptModel
    init(scriptModel: ScriptModel) {
        self.scriptModel = scriptModel
        
        self.reload()
        self.addObserver()
    }
    
    func reload() {
        scriptModel.package.updateFiles()
        self.files = scriptModel.package.listFiles()
    }
    
    
    func addObserver() {
        NotificationCenter.default.addObserver(forName: ImageDataObject.refreshNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
    }
}

struct FileListView: View {
    @ObservedObject var data: FileListDataObject
    
    init(scriptModel: ScriptModel) {
        self.data = FileListDataObject(scriptModel: scriptModel)
    }
    
    var body: some View {
        List {
            ForEach(data.files) { file in
                Text(file.relativePath)
            }
        }
        .refreshable {
            self.data.reload()
        }
    }
}

struct FileListView_Previews: PreviewProvider {
    static var previews: some View {
        FileListView(scriptModel: globalScriptModel)
    }
}
