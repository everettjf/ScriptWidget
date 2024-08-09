//
//  MarketplaceListView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/13.
//
//

import SwiftUI

struct MarketplaceListView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject var dataObject = MarketplaceListDataObject()
    let widgetSize: String
    let columns: [GridItem]
    
    let width: CGFloat
    let height: CGFloat
    
    let title: String
    
    @State var selectedWidget: MarketplaceWidgetModel?
    
    init(widgetSize: String) {
        self.widgetSize = widgetSize
        if self.widgetSize == "small" {
            self.width = 149
            self.height = 149
            self.title = "Marketplace - Small Widgets"
        } else if self.widgetSize == "medium" {
            self.width = 330
            self.height = 149
            self.title = "Marketplace - Medium Widgets"
        } else if self.widgetSize == "large" {
            self.width = 300
            self.height = 316
            self.title = "Marketplace - Large Widgets"
        } else {
            self.width = 149
            self.height = 149
            self.title = "Marketplace - Unknown Size (Internal Error)"
        }
        self.columns = [
            GridItem(.adaptive(minimum: self.width, maximum: self.width), spacing: 5)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                
                Text(title)
                    .font(.headline)
                Spacer()
                
                Button (action: {
                    presentationMode.wrappedValue.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                })
            }
            .padding()
            ScrollView(.vertical) {
                LazyVGrid (columns: self.columns){
                    ForEach(dataObject.widgets) { item in
                        MarketplaceHomeItemView(width: self.width, height: self.height,imageUrl: item.getImageURL(), name: item.name)
                            .onTapGesture {
                                self.selectedWidget = item
                            }
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .frame(idealWidth:800, idealHeight: 800)
        .navigationTitle("Widget Marketplace")
        .task {
            await self.dataObject.reload(widgetSize: self.widgetSize)
        }
        .sheet(item: $selectedWidget) { item in
            MarketplaceDetailView(widget: item)
        }
    }
}

struct MarketplaceListView_Previews: PreviewProvider {
    static var previews: some View {
        MarketplaceListView(widgetSize: "small")
    }
}
