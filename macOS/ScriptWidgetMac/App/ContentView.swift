//
//  ContentView.swift
//  Shared
//
//  Created by everettjf on 2022/1/14.
//

import SwiftUI

struct ContentView: View {
    @StateObject var store = SharedAppStore()
    
    var body: some View {
        NavigationView {
            SidebarView(store: store)
  
            EmptyHelloView()
                .toolbar {
                    ButtonOfficalSite()
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
