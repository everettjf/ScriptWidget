//
//  EditAttributesView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/11.
//

import SwiftUI
import SwiftyJSON

struct LabelTextField : View {
    @State var value : String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("NAME")
                .font(.headline)
            
            TextField("",text:$value)
                .padding(.all)
                .background(Color(red: 239.0/255.0, green: 243.0/255.0, blue: 244.0/255.0, opacity: 1.0))
        }
        .padding(.horizontal, 15)
    }
}

struct EditAttributesView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var keyboardHeightHelper = KeyboardHeightHelper()
    @State private var isShowingDeleteAlert = false
    
    @State private var inputName: String = ""
    
    let scriptModel: ScriptModel
    
    let actionDeleted: (() -> Void)?
    
    init(scriptModel: ScriptModel, actionDeleted: @escaping () -> Void) {
        self.scriptModel = scriptModel
        self.actionDeleted = actionDeleted
        
        _inputName = State(initialValue: scriptModel.name)
    }
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Text("Edit Attributes")
                    .font(.body)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button (action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                })
            }
            .padding()
            
            Form {
                
                Section(header: Text("Name")) {
                    TextField("Script Name", text: $inputName)
                }
                
                Section {
                    HStack {
                        Button(action: {}) {
                            Text("Cancel")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            self.presentationMode.wrappedValue.dismiss()
                        }
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Text("Save")
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            
                            // check rename
                            if scriptModel.name != self.inputName {
                                // need rename
                                let result = sharedScriptManager.renameScript(srcScriptId: scriptModel.name, destScriptId: self.inputName)
                                
                                if !result.0 {
                                    let errorMsg = result.1
                                    
                                    print("Rename Failed: \(errorMsg)")
                                    
                                    return
                                }
                                
                                NotificationCenter.default.post(name: ScriptWidgetListViewDataObject.scriptRenameNotification, object: nil, userInfo: ["newName" : self.inputName ])
                                
                            }
                            
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            
            if self.keyboardHeightHelper.keyboardHeight == 0 {
                Button(action: {
                    isShowingDeleteAlert = true
                }) {
                    Text("Delete")
                        .foregroundColor(.red)
                }
                .alert(isPresented: $isShowingDeleteAlert) {
                    Alert(title: Text("Delete Confirm"), message: Text("Delete \(scriptModel.name) ?"), primaryButton: .destructive(Text("Delete")) {
                        
                        // real delete
                        if sharedScriptManager.deleteScript(scriptId: scriptModel.name) {
                            
                            NotificationCenter.default.post(name: ScriptWidgetListViewDataObject.scriptDeleteNotification, object: nil)

                            // confirm
                            self.presentationMode.wrappedValue.dismiss()
                            
                            if let action = self.actionDeleted {
                                action()
                            }
                        }
                    }, secondaryButton: .cancel()
                    )
                }
                .padding(.bottom)
            }
        }
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

struct EditAttributesView_Previews: PreviewProvider {
    static var previews: some View {
        EditAttributesView(scriptModel: globalScriptModel, actionDeleted: {
            
        })
        .previewLayout(.fixed(width: 400, height: 600))
    }
}
