//
//  MarketplaceDetailView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/13.
//

import SwiftUI
import SDWebImageSwiftUI

struct MarketplaceDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let widget: MarketplaceWidgetModel
    
    @State var downloadStatus: String = ""
    @State var downloading: Bool = false
    @State var downloaded: Bool = false
    
    var snapshot: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(widget.snapshotsURLs(), id: \.self) { snapshotUrl in
                    
                    WebImage(url: snapshotUrl)
                        .placeholder {
                            ZStack {
                                Rectangle().foregroundColor(.gray)
                                ProgressView()
                            }
                        }
                        .resizable()
                        .frame(width: widget.previewSize().width, height: widget.previewSize().height)
                        .cornerRadius(10)
                }
            }
            .padding(.leading)
            .padding(.trailing)
        }
        
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                
                Text(widget.name)
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
            
            
            ZStack {
                Rectangle()
                    .fill(Color.secondary)
                
                snapshot
            }
            .frame(height: 320)
            
            VStack(alignment: .leading) {
                Text("Widget Name : \(widget.name)")
                    .font(.headline)
                Text("Author : \(widget.package.author)")
                    .font(.subheadline)
                Text("Description: \(widget.package.description)")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                
                Text("Files:")
                    .font(.subheadline)
                
                List {
                    ForEach(widget.package.files, id: \.self) { file in
                        Text("- \(file)")
                            .font(.subheadline)
                    }
                }
                .listStyle(.plain)
                
            }
            .frame(height: 150)
            .padding()
            
            Spacer()
            
            if !downloadStatus.isEmpty {
                HStack {
                    Spacer()
                    Text(downloadStatus)
                        .font(.callout)
                        .bold()
                        .padding(.leading)
                        .padding(.trailing)
                    Spacer()
                }
            }
            
            HStack {
                Spacer()
                
                Button(action: {
                    if downloading {
                        return
                    }
                    
                    if downloaded {
                        downloadStatus = "Already downloaded"
                        return
                    }
                    
                    Task {
                        downloading = true
                        let result = await sharedScriptManager.downloadPackage(model: self.widget, progress: { current, total in
                            downloadStatus = "Downloading \(current) / \(total)"
                        })
                        
                        downloading = false
                        if result.0 {
                            downloadStatus = "Succeed 🎉🎉🎉"
                            downloaded = true
                        } else {
                            downloadStatus = "Failed, please retry :)\n" + result.1
                            
                            MacKitUtil.alertWarn(title: "Failed download", message: downloadStatus)
                        }
                        
                        NotificationCenter.default.post(name: SharedAppStore.scriptCreateNotification, object: nil)
                    }
                }) {
                    if downloading {
                        Text("Downloading").fontWeight(.bold)
                    } else {
                        Text("Download").fontWeight(.bold)
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
}

struct MarketplaceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MarketplaceDetailView(widget: MarketplaceWidgetModel(
            name: "Is Friday",
            size: "small",
            package: MarketplaceJSONPackageModel(
                description: "Show is it friday today",
                author: "everettjf",
                snapshots: [
                    "snapshot/snapshot1.png"
                ], files: [
                    "main.jsx"
                ]
            )
        ))
    }
}
