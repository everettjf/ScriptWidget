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
                .font(getTextFont(size))
            
        }
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.3), radius: 3, x: 2, y: 2)
    }
    
    func getTextFont(_ viewSize: CGFloat) -> Font {
        if size >= 60 {
            return .title
        }
        if size <= 20 {
            return .footnote
        }
        return .body
    }
}



struct AppIconAutoImageView: View {
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
                .frame(width: size, height: size)
            
            HStack(alignment:.center, spacing: -15) {
                Text(String("S".uppercased()))
                    .foregroundColor(.black)
                    .font(.system(size: 170))
                    .shadow(radius: 10)
                
                Text(String("cript".uppercased()))
                    .foregroundColor(.black)
                    .font(.system(size: 20))
                    .rotationEffect(Angle(degrees: 90))
                    .shadow(radius: 2)

                Text(String("W".uppercased()))
                    .foregroundColor(.black)
                    .font(.system(size: 170))
                    .shadow(radius: 10)
                
                Text(String("idget".uppercased()))
                    .foregroundColor(.black)
                    .font(.system(size: 20))
                    .rotationEffect(Angle(degrees: 90))
                    .shadow(radius: 2)
            }
            
        }
        .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.3), radius: 3, x: 2, y: 2)
    }
}

struct NameAutoImageView_Previews: PreviewProvider {
    static var previews: some View {
        NameAutoImageView(name: "hello", colors: [Color.blue, Color.red], size: 20)
            .previewLayout(.sizeThatFits)
            .padding()
        NameAutoImageView(name: "hello", colors: [Color.blue, Color.red], size: 40)
            .previewLayout(.sizeThatFits)
            .padding()
        
        NameAutoImageView(name: "hello", colors: [Color.blue, Color.red], size: 80)
            .previewLayout(.sizeThatFits)
            .padding()
        
        AppIconAutoImageView(name: "SW", colors: getGradientColorsWithString(string: "SW"), size: 512)
            .previewLayout(.sizeThatFits)
            .padding()
        
    }
}
