//
//  ResourceCodeView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/1/29.
//

import SwiftUI
import AlertToast

struct ResourceCodeView: View {
    
    @Environment(\.presentationMode) var presentationMode
    
    @State var showingToast = false
    @State var toastMessage = ""

    let model: ScriptModel
    
    
    init(model: ScriptModel) {
        self.model = model
        
        self.model.package.updateImages()
    }
    
    func showToast(_ message: String) {
        toastMessage = message
        showingToast.toggle()
    }
    
    var body: some View {
        content
        .toast(isPresenting: $showingToast) {
            AlertToast(type: .regular, title: toastMessage)
        }
    }
    
    var content: some View {
        NavigationView {
            List{
                Section(header: Text("Images")) {
                    NavigationLink(destination: ImageListView(model: model)) {
                        Label("Images", systemImage: "photo")
                    }
                }
                Section(header: Text("Files")) {
                    NavigationLink(destination: FileListView(model: model)) {
                        Label("Files", systemImage: "doc.plaintext")
                    }
                }
                Section(header: Text("Documents")) {
                    NavigationLink(destination: SettingComponentsView()) {
                        Label("Components", systemImage: "command")
                    }
                    NavigationLink(destination: SettingAPIsView()) {
                        Label("APIs", systemImage: "book")
                    }
                    NavigationLink(destination: SettingTemplatesView()) {
                        Label("Templates", systemImage: "simcard")
                    }
                }
                
            }
            .navigationBarTitle(Text("Resources"), displayMode: .inline)
            .navigationBarItems(
                trailing: Button (action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                        .padding()
                })
            )
        }
    }
}

struct ResourceCodeView_Previews: PreviewProvider {
    static var previews: some View {
        ResourceCodeView(model: globalScriptModel)
            .preferredColorScheme(.dark)
            .previewDevice("iPhone 12 Pro")
        
    }
}
