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

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    GroupBox (label:
                                SettingsLabelView(title: "ScriptWidget", image: "info.circle")) {
                        Divider().padding(.vertical, 4)

                        HStack(alignment: .center, spacing: 10) {
                            Image(uiImage: UIImage(named:AppHelper.getCurrentIconName()) ?? UIImage())
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(9)
                            
                            Text("ScriptWidget enables you create simple widget using JavaScript with JSX like label style code. Let's create wonderfull widget in few miniutes.")
                                .font(.footnote)
                        }
                        SettingsLinkRowView(name: "Documents", label: "View", urlString: "https://scriptwidget.app/docs")

                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Resource", image: "doc.on.doc")) {
                        NavigationLink(destination: ImagesView()) {
                            SettingsTextRowView(name: "Images", content: "View")
                        }
                        NavigationLink(destination: ComponentsView()) {
                            SettingsTextRowView(name: "Components", content: "View")
                        }
                        NavigationLink(destination: APIsView()) {
                            SettingsTextRowView(name: "APIs", content: "View")
                        }
                        NavigationLink(destination: TemplatesView()) {
                            SettingsTextRowView(name: "Templates", content: "View")
                        }
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Refresh Widgets", image: "paintbrush")) {
                        Divider().padding(.vertical, 4)

                        HStack {
                            Text("If you wish, you can refresh all the widgets manually. After tap the button, all the widgets will re-run the JavaScript code behind them.")
                                .padding(.vertical, 8)
                                .layoutPriority(1)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                            
                            CountDownButton(text: "Refresh".uppercased(), waitSeconds: 10) {
                                WidgetCenter.shared.reloadAllTimelines()
                            }
                        }
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "iCloud", image: "icloud")) {
                        Divider().padding(.vertical, 4)
                        
                        SettingsICloudView()
                    }
                    GroupBox (label: SettingsLabelView(title: "Buy me a coffee", image: "wand.and.stars.inverse")) {
                        
                        NavigationLink(destination: BuyMeCoffeeView()) {
                            SettingsTextRowView(name: "Buy me a coffee", content: "View")
                        }
                        
                        if sharedStoreManager.hadCoffee() {
                            NavigationLink(destination: AppIconsView()) {
                                SettingsTextRowView(name: "App Icons", content: "View")
                            }
                        }
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Group", image: "person.3")) {
                        SettingsGroupView()
                    }
                    
                    GroupBox (label: SettingsLabelView(title: "Application", image: "appclip")) {
                        SettingsLinkRowView(name: "Developer", label: "everettjf", urlString: "https://twitter.com/everettjf")
                        SettingsLinkRowView(name: "Designer", label: "everettjf", urlString: "https://everettjf.github.io")
                        SettingsLinkRowView(name: "Website", label: "scriptwidget.app", urlString: "https://scriptwidget.app")
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
