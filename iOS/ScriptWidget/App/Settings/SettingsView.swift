//
//  SettingsView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/6.
//

import SwiftUI
import WidgetKit

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    var body: some View {
        content
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
    }

    var content: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    GroupBox (label: SettingsLabelView(title: "ScriptWidget", image: "info.circle")) {
                        NavigationLink(destination: SettingTemplatesView()) {
                            SettingsTextRowView(name: "Templates", content: "")
                        }
                    }
                    
                    
                    GroupBox (label: SettingsLabelView(title: "Refresh", image: "paintbrush")) {
                        Divider().padding(.vertical, 4)

                        HStack {
                            Text("Force all widgets to re-run their JavaScript code. This is useful after you've made changes to the code.")
                                .padding(.vertical, 8)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Button {
                                WidgetCenter.shared.reloadAllTimelines()
                                
                                showAlert("Widgets are refreshed :)")
                            } label: {
                                Image(systemName: "paintbrush")
                                    .font(.caption)
                                Text("Refresh")
                                    .font(.caption)
                                    .width(50)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    
                    GroupBox (label: SettingsLabelView(title: "Export & Import", image: "info.circle")) {
                        
                        NavigationLink(destination: ExportView()) {
                            SettingsTextRowView(name: "Export", content: "")
                        }
                        NavigationLink(destination: ImportView()) {
                            SettingsTextRowView(name: "Import", content: "")
                        }
                    }
                    
                    
                    GroupBox (label: SettingsLabelView(title: "iCloud", image: "icloud")) {
                        Divider().padding(.vertical, 4)
                        
                        SettingsICloudView()
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Application", image: "appclip")) {
                        
                        NavigationLink(destination: AppIconsView()) {
                            SettingsTextRowView(name: "App Icons", content: "")
                        }
                        SettingsLinkRowView(name: "Website", label: "https://xnu.app/scriptwidget", urlString: "https://xnu.app/scriptwidget")
                        SettingsLinkRowView(name: "Discord", label: "", urlString: "https://discord.gg/eGzEaP6TzR")
                        SettingsLinkRowView(name: "Developer", label: "everettjf", urlString: "https://twitter.com/everettjf")
                        SettingsLinkRowView(name: "Special Thanks", label: "Reina", urlString: "https://github.com/Reinachan")
                        SettingsTextRowView(name: "Version", content: AppHelper.getAppVersion())
                    }
                    
                }
                .navigationBarTitle(Text("Settings"), displayMode: .large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Label("Close", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.dark)
            .previewDevice("iPhone 12 Pro")
    }
}
