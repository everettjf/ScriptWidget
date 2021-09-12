//
//  NameAutoImageView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/10.
//

import SwiftUI

struct NameAutoImageView: View {
    let name: String
    let colors: [Color]
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    gradient: .init(colors: colors),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .cornerRadius(size / 5)
                .frame(width: size, height: size)
            
            Text(String(name.uppercased().prefix(2)))
                .foregroundColor(.black)
                .fontWeight(.bold)
                .shadow(radius: 10)
                .font( size >= 60 ? .title : .body)
            
        }
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.3), radius: 3, x: 2, y: 2)
    }
}

struct NameAutoImageView_Previews: PreviewProvider {
    static var previews: some View {
        NameAutoImageView(name: "hello", colors: [Color.blue, Color.red], size: 50)
            .previewLayout(.sizeThatFits)
            .padding()
        
            NameAutoImageView(name: "hello", colors: [Color.blue, Color.red], size: 80)
                .previewLayout(.sizeThatFits)
                .padding()
    }
}
