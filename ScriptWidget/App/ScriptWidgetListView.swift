//
//  ScriptWidgetListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import SwiftUI
import UIKit

class ScriptWidgetListViewDataObject : ObservableObject {
    public static let scriptCreateNotification = Notification.Name("ScriptWidgetListViewDataObjectNewScript")
    public static let scriptRenameNotification = Notification.Name("ScriptWidgetListViewDataObjectRenameScript")
    public static let scriptDeleteNotification = Notification.Name("ScriptWidgetListViewDataObjectDeleteScript")

    @Published var models = [ScriptModel]()

    init() {
        reload()
        
        NotificationCenter.default.addObserver(forName: ScriptWidgetListViewDataObject.scriptCreateNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
        
        NotificationCenter.default.addObserver(forName: ScriptWidgetListViewDataObject.scriptRenameNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
        
        NotificationCenter.default.addObserver(forName: ScriptWidgetListViewDataObject.scriptDeleteNotification, object: nil, queue: OperationQueue.main) { (noti) in
            self.reload()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main) { (noti) in
            
            if let userDefaults = UserDefaults(suiteName: "group.everettjf.scriptwidget") {
                if let _ = userDefaults.string(forKey: "need_update_list") {
                    userDefaults.removeObject(forKey: "need_update_list")
                    self.reload()
                }
            }
        }
    }
    
    func reload() {
        DispatchQueue.global().async { [self] in
            let items = sharedScriptManager.listScripts()
            DispatchQueue.main.async {
                self.models = items
            }
        }
    }
}

struct ScriptWidgetListView: View {
    
    @ObservedObject var dataObject = ScriptWidgetListViewDataObject()
    
        
    var body: some View {
        if dataObject.models.isEmpty {
            EmptyListBackgroundView()
        } else {
            List {
                ForEach(dataObject.models) { item in
                    NavigationLink(destination: ScriptCodeEditorView(mode: .editor, scriptModel: item)) {
                        WidgetRowView(model: item)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct ScriptWidgetListView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptWidgetListView()
    }
}
