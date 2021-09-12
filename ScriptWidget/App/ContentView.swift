//
//  ContentView.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/10/4.
//

import SwiftUI


struct ContentView: View {
    
    
    
    @State private var isShowingSettings: Bool = false
    @State private var isShowingCreateGuide: Bool = false
    
    
    var body: some View {
        NavigationView {
            ScriptWidgetListView()
            .navigationTitle("ScriptWidget")
            .navigationBarItems(
                leading:Button(action: {
                    isShowingSettings = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .padding(.trailing, 30)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                },
                trailing:Button(action: {
                    isShowingCreateGuide = true
                }) {
                    Image(systemName: "plus.square")
                        .padding(.leading, 30)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                }
                .sheet(isPresented: $isShowingCreateGuide) {
                    CreateGuideView()
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
