//
//  ScriptWidgetPlaceholderView.swift
//  ScriptWidgetMacWidgetExtension
//
//  Created by everettjf on 2022/1/24.
//

import SwiftUI
import WidgetKit

struct ScriptWidgetPlaceholderView: View {
    var body: some View {
        VStack (spacing: 20) {
            Image(systemName: "lessthan")
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
        ScriptWidgetPlaceholderView()
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        ScriptWidgetPlaceholderView()
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        ScriptWidgetPlaceholderView()
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
