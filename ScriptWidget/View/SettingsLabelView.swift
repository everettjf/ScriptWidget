//
//  SettingsLabelView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/6.
//

import SwiftUI

struct SettingsLabelView: View {
    
    let title: String
    let image: String
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .fontWeight(.bold)
            Spacer()
            Image(systemName: image)
        }
    }
}

struct SettingsLabelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsLabelView(title: "Document", image: "info.circle")
                .preferredColorScheme(.light)
                .previewLayout(.sizeThatFits)
                .padding()
            SettingsLabelView(title: "Document", image: "info.circle")
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
