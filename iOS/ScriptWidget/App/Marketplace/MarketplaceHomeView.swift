//
//  MarketplaceView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/2/9.
//

import SwiftUI
import SDWebImageSwiftUI

struct MarketplaceHeaderLabelView: View {
    let name: String
    let widgetSize: String
    let onAppear: () -> Void
    let onDisappear: () -> Void
    
    var body: some View {
        HStack {
            Text(LocalizedStringKey(name))
                .font(.headline)
            Spacer()
            NavigationLink(destination:
                            MarketplaceListView(widgetSize: widgetSize)
                            .onAppear { self.onAppear() }     // !!
                            .onDisappear { self.onDisappear() } // !!
            ) {
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
                .cornerRadius(20)
            Text("\(name)")
                .font(.subheadline)
        }
    }
}

struct MarketplaceItemMoreView : View {
    
    let height: CGFloat
    
    var body: some View {
        VStack {
            ZStack {
                Rectangle()
                    .foregroundColor(.systemGray)
                    .frame(width: 50, height: height)
                    .cornerRadius(10)
                    .opacity(0.2)
                Text("More")
            }
            Text(" ")
                .font(.subheadline)
        }
    }
}

struct MarketplaceHomeView: View {
    private var idiom : UIUserInterfaceIdiom { UIDevice.current.userInterfaceIdiom }

    @State private var tabBar: UITabBar! = nil
    
    @StateObject var dataObject = MarketplaceHomeDataObject()
    
    @State var selectedWidget: MarketplaceWidgetModel?
    
    var body: some View {
        NavigationView {
            content
                .navigationTitle("Marketplace")
                .navigationBarItems(
                    trailing: Button(action: {
                        if let url = URL(string: "https://scriptwidget.app/docs/marketplace/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "plus.bubble")
                            .padding(.leading, 30)
                            .padding(.top, 5)
                            .padding(.bottom, 5)
                    }
                )
            
            Text("Hello Marketplace :)")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(TabBarAccessor { tabbar in   // << here !!
            if idiom != .pad {
                self.tabBar = tabbar
            }
        })
        .sheet(item: $selectedWidget) { item in
            MarketplaceDetailView(widget: item)
        }
    }
    
    func showTabBar(_ visible: Bool) {
        guard let tabBar = tabBar else {
            return
        }

        if visible {
            tabBar.isHidden = false
        } else {
            tabBar.isHidden = true
        }
    }
    @ViewBuilder
    var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            MarketplaceHeaderLabelView(name: "Small Widgets", widgetSize: "small", onAppear: {
                showTabBar(false)
            }, onDisappear: {
                showTabBar(true)
            })
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.smallWidgets.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(dataObject.smallWidgets) { item in
                            MarketplaceHomeItemView(width: 149, height: 149,imageUrl: item.getImageURL(), name: item.name)
                                .onTapGesture {
                                    self.selectedWidget = item
                                }
                        }
                        
                        NavigationLink(destination:
                                        MarketplaceListView(widgetSize: "small")
                                        .onAppear { showTabBar(false) }     // !!
                                        .onDisappear { showTabBar(true) } // !!
                        ) {
                            MarketplaceItemMoreView(height: 149)
                        }
                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
            
            MarketplaceHeaderLabelView(name: "Medium Widgets", widgetSize: "medium", onAppear: {
                showTabBar(false)
            }, onDisappear: {
                showTabBar(true)
            })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.mediumWidgets.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(dataObject.mediumWidgets) { item in
                            MarketplaceHomeItemView(width: 330, height: 149,imageUrl: item.getImageURL(), name: item.name)
                                .onTapGesture {
                                    self.selectedWidget = item
                                }
                        }
                        
                        
                        NavigationLink(destination:
                                        MarketplaceListView(widgetSize: "medium")
                                        .onAppear { self.tabBar.isHidden = true }     // !!
                                        .onDisappear { self.tabBar.isHidden = false } // !!
                        ) {
                            MarketplaceItemMoreView(height: 149)
                        }
                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
            
            
            MarketplaceHeaderLabelView(name: "Large Widgets", widgetSize: "large", onAppear: {
                showTabBar(false)
            }, onDisappear: {
                showTabBar(true)
            })
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if dataObject.largeWidgets.isEmpty {
                        ProgressView()
                    } else {
                        ForEach(dataObject.largeWidgets) { item in
                            MarketplaceHomeItemView(width: 300, height: 316,imageUrl: item.getImageURL(), name: item.name)
                                .onTapGesture {
                                    self.selectedWidget = item
                                }
                        }
                        
                        NavigationLink(destination:
                                        MarketplaceListView(widgetSize: "large")
                                        .onAppear { self.tabBar.isHidden = true }     // !!
                                        .onDisappear { self.tabBar.isHidden = false } // !!
                        ) {
                            MarketplaceItemMoreView(height: 316)
                        }
                    }
                }
                .padding(.leading)
                .padding(.trailing)
            }
        }
        .task {
            await self.dataObject.reload()
        }
        .refreshable {
            await self.dataObject.reload()
        }
    }
}

struct MarketplaceView_Previews: PreviewProvider {
    static var previews: some View {
        MarketplaceHomeView()
    }
}
