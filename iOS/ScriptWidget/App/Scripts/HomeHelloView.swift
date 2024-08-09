//
//  HomeHelloView.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/2/27.
//

import SwiftUI

struct HomeHelloView: View {
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

struct HomeHelloView_Previews: PreviewProvider {
    static var previews: some View {
        HomeHelloView()
    }
}
