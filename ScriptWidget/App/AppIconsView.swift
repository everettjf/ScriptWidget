//
//  AppIconsView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/16.
//

import SwiftUI

struct AppIconsView: View {
    
    private var iconNames = AppHelper.getAlternateIconNames()
    
    private var gridItemLayout = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItemLayout, spacing: 20) {
                ForEach(iconNames, id: \.self) { item in
                    
                    Button(action: {
                        print("item = \(item)")
                        
                        UIApplication.shared.setAlternateIconName(item) { (error) in
                            if let err = error {
                                print("failed set icon : \(err)")
                            } else {
                                print("succeed change icon")
                            }
                        }
                    }) {
                        Image(uiImage: UIImage(named: item) ?? UIImage())
                            .resizable()
                            .frame(width: 50, height: 50)
                            .cornerRadius(10)
                        
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitle(Text("App Icons"), displayMode: .inline)
    }
}

struct AppIconsView_Previews: PreviewProvider {
    static var previews: some View {
        AppIconsView()
    }
}
