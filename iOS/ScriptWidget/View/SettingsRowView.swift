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
                    Text(LocalizedStringKey(name))
                    
                    Spacer()
                    
                    Text(LocalizedStringKey(label))
                    
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
                Text(LocalizedStringKey(name))
                
                Spacer()
                
                Text(content)
                    
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.blue)
            }
        }
    }
}
