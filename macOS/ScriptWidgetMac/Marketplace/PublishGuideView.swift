//
//  PublishGuideView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/15.
//

import SwiftUI

struct PublishGuideView: View {
    @Environment(\.dismiss) var dismiss
    
    let model: ScriptModel

    var body: some View {
        VStack(alignment: .leading) {
            
            HStack {
                Spacer()
                
                Text("Publishing: \(model.name)")
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
        
            Text("For how to publish to marketplace, please visit : https://scriptwidget.app/docs/marketplace/")
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            
            Spacer()
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("OK").frame(width:50)
                }
            }
        }
        .frame(width: 300, height: 160)
        .padding()
    }
}

struct PublishGuideView_Previews: PreviewProvider {
    static var previews: some View {
        PublishGuideView(model:globalScriptModel)
    }
}
