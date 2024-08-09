//
//  EmptyHelloView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/26.
//

import SwiftUI

struct EmptyHelloView: View {
    var body: some View {
        VStack (spacing: 20) {
            Image(systemName: "lessthan")
                .font(.system(size: 70, weight: .bold, design: .monospaced))
            
            Text("Hello ScriptWidget :)")
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(Color.gray.opacity(0.75))
        .padding()
    }
}

struct EmptyHelloView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyHelloView()
    }
}
