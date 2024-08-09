//
//  MarketplaceListView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/2/9.
//

import SwiftUI

struct MarketplaceListView: View {
    @StateObject var dataObject = MarketplaceListDataObject()
    let widgetSize: String
    let columns: [GridItem]
    
    let width: CGFloat
    let height: CGFloat
    
    @State var selectedWidget: MarketplaceWidgetModel?

    init(widgetSize: String) {
        self.widgetSize = widgetSize
        if self.widgetSize == "small" {
            self.width = 149
            self.height = 149
        } else if self.widgetSize == "medium" {
            self.width = 330
            self.height = 149
        } else {
            self.width = 300
            self.height = 316
        }
        self.columns = [
            GridItem(.adaptive(self.width), spacing: 5),
        ]
    }
    
    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid (columns: self.columns){
                ForEach(dataObject.widgets) { item in
                    MarketplaceHomeItemView(width: self.width, height: self.height,imageUrl: item.getImageURL(), name: item.name)
                        .onTapGesture {
                            self.selectedWidget = item
                        }
                }
            }
            .refreshable {
                await self.dataObject.reload(widgetSize: self.widgetSize)
            }
        }
        .navigationBarTitle("Widget Marketplace", displayMode: .inline)
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
