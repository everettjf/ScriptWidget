//
//  ScriptWidgetPlaceholderView.swift
//  ScriptWidgetWidget
//
//  Created by everettjf on 2021/3/1.
//

import SwiftUI
import WidgetKit

struct ScriptWidgetPlaceholderView: View {
    var body: some View {
        VStack (spacing: 20) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 50, weight: .bold, design: .monospaced))
            
            Text("ScriptWidget")
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(Color.gray.opacity(0.75))
        .padding()
    }
}

struct ScriptWidgetPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScriptWidgetPlaceholderView()
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
