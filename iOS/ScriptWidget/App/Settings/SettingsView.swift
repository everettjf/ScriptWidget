//
//  SettingsView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/6.
//

import SwiftUI
import WidgetKit
import AlertToast

struct SettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode
    @State var showingToast = false
    @State var toastMessage = ""
    
    
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    GroupBox (label: SettingsLabelView(title: "ScriptWidget", image: "info.circle")) {
                        SettingsLinkRowView(name: "Documents", label: "", urlString: "https://scriptwidget.app/docs")
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
                                
                                showToast("Widgets are refreshed :)")
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
                        
                        NavigationLink(destination: ExportImportView()) {
                            SettingsTextRowView(name: "Export", content: "")
                        }
                        NavigationLink(destination: ExportImportView()) {
                            SettingsTextRowView(name: "Import", content: "")
                        }
                    }
                    
                    
                    GroupBox (label: SettingsLabelView(title: "iCloud", image: "icloud")) {
                        Divider().padding(.vertical, 4)
                        
                        SettingsICloudView()
                    }
                    
                    
                    GroupBox (label: SettingsLabelView(title: "Buy me a coffee", image: "lessthan")) {
                        
                        NavigationLink(destination: BuyMeCoffeeView()) {
                            SettingsTextRowView(name: "Buy me a coffee", content: "")
                        }
                        
                        if sharedStoreManager.hadCoffee() {
                            NavigationLink(destination: AppIconsView()) {
                                SettingsTextRowView(name: "App Icons", content: "")
                            }
                        }
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Application", image: "appclip")) {
                        SettingsLinkRowView(name: "Website", label: "https://scriptwidget.app", urlString: "https://scriptwidget.app")
                        SettingsLinkRowView(name: "Discord", label: "", urlString: "https://discord.gg/eGzEaP6TzR")
                        SettingsLinkRowView(name: "Mail", label: "", urlString: "mailto:everettjf@live.com?subject=ScriptWidget_Feedback")
                        SettingsLinkRowView(name: "Developer", label: "everettjf", urlString: "https://twitter.com/everettjf")
                        SettingsLinkRowView(name: "Special Thanks", label: "Reina", urlString: "https://github.com/Reinachan")
                        SettingsTextRowView(name: "Version", content: AppHelper.getAppVersion())
                    }
                    
                }
                .navigationBarTitle(Text("Settings"), displayMode: .large)
                .navigationBarItems(
                    trailing: Button (action: {
                        presentationMode.wrappedValue.dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                            .padding()
                    })
                )
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
