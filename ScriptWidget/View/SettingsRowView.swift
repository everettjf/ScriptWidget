//
//  SettingsRowView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/6.
//

import SwiftUI
import UIKit

struct SettingsLinkRowView: View {
    
    let name: String
    
    // link mode
    var label: String
    var urlString: String
    
    var body: some View {
        VStack {
            Divider().padding(.vertical, 4)
            
            Button(action: {
                if let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text(name)
                    
                    Spacer()
                    
                    Text(label)
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }

        }
    }
}

struct SettingsTextRowView: View {
    
    let name: String
    
    var content: String
    
    var body: some View {
        VStack {
            Divider().padding(.vertical, 4)

            HStack {
                Text(name)
                
                Spacer()
                
                Text(content)
                    
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct SettingsRowView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsLinkRowView(name: "Documents", label: "View", urlString: "https://scriptwidget.app/docs")
            .preferredColorScheme(.light)
            .previewLayout(.fixed(width: 375, height: 60))
            .padding()
        
        SettingsTextRowView(name: "Images", content: "View")
            .preferredColorScheme(.light)
            .previewLayout(.fixed(width: 375, height: 60))
            .padding()
        
        SettingsLinkRowView(name: "Website", label: "Pale Blue Dot", urlString: "https://everettjf.github.io")
            .preferredColorScheme(.dark)
            .previewLayout(.fixed(width: 375, height: 60))
            .padding()
    }
}
