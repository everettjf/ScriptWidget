//
//  EmptyListBackgroundView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//


import SwiftUI

struct EmptyListBackgroundView: View {
    var body: some View {
        VStack (spacing: 5) {
            Text("Create your first widget by tapping the plus button upper-right :)")
                .multilineTextAlignment(.leading)
                .lineLimit(10)
                .font(.headline)
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
