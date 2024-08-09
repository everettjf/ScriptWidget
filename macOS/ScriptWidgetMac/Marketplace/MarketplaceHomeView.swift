//
//  MarketplaceHomeView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/13.
//


import SwiftUI
import SDWebImageSwiftUI

struct MarketplaceHeaderLabelView: View {
    let name: String
    let widgetSize: String
    let action: () -> Void
    
    var body: some View {
        HStack {
            Text(name)
                .font(.headline)
            Spacer()
            Button {
                action()
            } label: {
                HStack {
                    Image(systemName: "ellipsis.circle")
                    Text("More")
                        .font(.headline)
                }
            }
        }
        .padding(.leading)
        .padding(.trailing)
    }
}

struct MarketplaceHomeItemView : View {
    let width: CGFloat
    let height: CGFloat
    let imageUrl: URL?
    let name: String
    
    var body: some View {
        VStack {
            WebImage(url: imageUrl)
                .placeholder {
                    ZStack {
                        Rectangle().foregroundColor(.gray)
                        ProgressView()
                    }
                }
                .resizable()
                .frame(width: width, height: height)
                .cornerRadius(10)
            Text("\(name)")
                .font(.subheadline)
        }
    }
}

struct MarketplaceItemMoreView : View {
    let height: CGFloat
    let action: () -> Void
    var body: some View {
        VStack {
            ZStack {
                Rectangle()
                    .foregroundColor(Color.gray)
                    .frame(width: 50, height: height)
                    .cornerRadius(10)
                    .opacity(0.2)
                Button {
                    action()
                } label: {
                    Text("More")
                        .font(.headline)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Text(" ")
                .font(.subheadline)
        }
    }
}

struct MarketplaceSelectedMoreModel : Identifiable {
    let id = UUID()
    let type: String
}

struct MarketplaceHomeView: View {
    
    @StateObject var dataObject = MarketplaceHomeDataObject()
    
    @State var selectedWidget: MarketplaceWidgetModel? = nil
    
    @State var selectedWidgetListSize: MarketplaceSelectedMoreModel? = nil
    
    var body: some View {
        content
        .navigationTitle("Marketplace")
        .sheet(item: $selectedWidget) { item in
            MarketplaceDetailView(widget: item)
        }
        .sheet(item: $selectedWidgetListSize) { item in
            MarketplaceListView(widgetSize: item.type)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    MacKitUtil.openUrl("https://scriptwidget.app/docs/marketplace")
                }) {
                    Image(systemName: "plus.bubble")
                }
            }
        }
    }
    
    @ViewBuilder
    var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            MarketplaceHeaderLabelView(name: "Small Widgets", widgetSize: "small") {
                self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "small")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.smallWidgets.isEmpty {
                        ProgressView()
                    }
                    ForEach(dataObject.smallWidgets) { item in
                        MarketplaceHomeItemView(width: 149, height: 149,imageUrl: item.getImageURL(), name: item.name)
                            .onTapGesture {
                                self.selectedWidget = item
                            }
                    }
                    
                    MarketplaceItemMoreView(height: 149) {
                        self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "small")

                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
            
            MarketplaceHeaderLabelView(name: "Medium Widgets", widgetSize: "medium") {
                self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "medium")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.mediumWidgets.isEmpty {
                        ProgressView()
                    }
                    ForEach(dataObject.mediumWidgets) { item in
                        MarketplaceHomeItemView(width: 330, height: 149,imageUrl: item.getImageURL(), name: item.name)
                            .onTapGesture {
                                self.selectedWidget = item
                            }
                    }
                    
                    MarketplaceItemMoreView(height:149) {
                        self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "medium")
                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
            
            
            MarketplaceHeaderLabelView(name: "Large Widgets", widgetSize: "large") {
                self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "large")
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.largeWidgets.isEmpty {
                        ProgressView()
                    }
                    ForEach(dataObject.largeWidgets) { item in
                        MarketplaceHomeItemView(width: 300, height: 316,imageUrl: item.getImageURL(), name: item.name)
                            .onTapGesture {
                                self.selectedWidget = item
                            }
                    }
                    
                    MarketplaceItemMoreView(height:316) {
                        self.selectedWidgetListSize = MarketplaceSelectedMoreModel(type: "large")
                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
        }
        .task {
            await self.dataObject.reload()
        }
    }
}
