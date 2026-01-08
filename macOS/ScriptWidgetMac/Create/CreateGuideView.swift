//
//  CreateGuideView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/18.
//

import SwiftUI

let defaultCreateScriptContent = """

//
// ScriptWidget
// https://xnu.app/scriptwidget
//
//

// widget-size : large,medium,small
const widget_size = $getenv("widget-size");

// parameter
const widget_param = $getenv("widget-param");

$render(
  <vstack frame="max">
    <text font="title">Hello New Widget</text>
    <text font="caption">{widget_size}</text>
    <text font="caption">{widget_param}</text>
  </vstack>
);

"""

struct CreateGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    @State var enteredText: String = "A New Widget"
    
    var body: some View {
        VStack(alignment:.leading) {
            Text("Script name :")
                .font(.headline)
            
            TextField("", text: $enteredText)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Create") {
                    
                    let inputText = enteredText.trim()
                    if inputText.isEmpty {
                        MacKitUtil.alertWarn(title: "Invalid name", message: "Name can not be empty")
                        return
                    }
                    
                    if !inputText.checkIfValidFileName() {
                        MacKitUtil.alertWarn(title: "Invalid name", message: "Please make sure the widget name is an valid file name")
                        return;
                    }
                    
                    
                    // image copy path
                    // todo
                    
                    let scriptName = inputText
                    let result = sharedScriptManager.createScript(content: defaultCreateScriptContent, recommendPackageName: scriptName, imageCopyPath: nil)

                    if !result.0 {
                        print("Create failed : \(result.1)")
                        MacKitUtil.alertWarn(title: "Create failed", message: "Please retry or relaunch app :)\nError : \(result.1)")
                        return
                    }
                    
                    NotificationCenter.default.post(name: SharedAppStore.scriptCreateNotification, object: nil)
                    
                    dismiss()
                }
            }
        }
        .frame(width: 300, height: 100)
        .padding()
    }
}

struct CreateGuideView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGuideView()
    }
}
