//
//  EmptyListBackgroundView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/3/1.
//

import SwiftUI

struct EmptyListBackgroundView: View {
    var body: some View {
        VStack (spacing: 20) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 70, weight: .bold, design: .monospaced))
            
            Text("ScriptWidget")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Create your first widget by tapping the plus button upper-right of screen :)")
                .font(.headline)
                .padding(.bottom, 100)
                .padding(.leading, 10)
                .padding(.trailing, 10)
        }
        .foregroundColor(Color.gray.opacity(0.75))
        .padding()
    }
}

struct EmptyListBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyListBackgroundView()
    }
}
