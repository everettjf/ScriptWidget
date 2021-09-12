//
//  ScriptWidgetElementGradient.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/21.
//

import Foundation
import SwiftUI
import SwiftyJSON

/*
 
 LinearGradient(gradient: Gradient(colors: [.blue, .white, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
 
 RadialGradient(gradient: Gradient(colors: [.blue, .black]), center: .center, startRadius: 2, endRadius: 650)
 
 AngularGradient(gradient: Gradient(colors: [.green, .blue, .black, .green, .blue, .black, .green]), center: .center)
 
 
 let linearGradient = {
 type: "linear",
 colors: ["blue","white","pink"],
 startPoint: "topLeading",
 endPoint: "bottomTrailing"
 }
 
 let radialGradient = {
 type: "radial",
 colors: ["orange", "red", "white"],
 center: "center",
 startRadius: 100,
 endRadius: 470
 }
 
 let angularGradient = {
 type: "angular",
 colors: ["green", "blue", "black", "green", "blue", "black", "green"],
 center: "center"
 }
 
 
 */


class ScriptWidgetElementGradient {
    
    /*
     "gradient:{\"type\":\"linear\",\"colors\":[\"blue\",\"white\",\"pink\"],\"startPoint\":\"topLeading\",\"endPoint\":\"bottomTrailing\"}"
     
     */
    static func getGradient(_  gradientValue: String) -> some View {
        
        if !gradientValue.starts(with: "gradient:") {
            return AnyView(Color.clear)
        }
        
        let jsonString = gradientValue.dropFirst("gradient:".count)
        if let jsonData = jsonString.data(using: .utf8)  {
            
            do {
                let json = try JSON(data: jsonData)
                
                let type = json["type"].stringValue
                
                if type == "linear" {
                    // colors
                    var colors: [Color] = []
                    for colorValue in json["colors"].arrayValue {
                        if let color = ScriptWidgetAttributeColor.getColorFromColorValue(colorValue.stringValue) {
                            colors.append(color)
                        } else {
                            colors.append(Color.clear)
                        }
                    }
                    
                    // start point
                    let startPoint = ScriptWidgetElementPoint.getPointFromPointValue(json["startPoint"].stringValue)
                    // end point
                    let endPoint = ScriptWidgetElementPoint.getPointFromPointValue(json["endPoint"].stringValue)
                    
                    return AnyView(LinearGradient(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint))
                    
                } else if type == "radial" {
                    // colors
                    var colors: [Color] = []
                    for colorValue in json["colors"].arrayValue {
                        if let color = ScriptWidgetAttributeColor.getColorFromColorValue(colorValue.stringValue) {
                            colors.append(color)
                        } else {
                            colors.append(Color.clear)
                        }
                    }
                    
                    // center
                    let center = ScriptWidgetElementPoint.getPointFromPointValue(json["center"].stringValue)
                    
                    let startRadius = json["startRadius"].doubleValue
                    let endRadius = json["endRadius"].doubleValue
                    
                    return AnyView(RadialGradient(gradient: Gradient(colors: colors), center: center, startRadius: CGFloat(startRadius), endRadius: CGFloat(endRadius)))
                    
                    
                } else if type == "angular" {
                    // colors
                    var colors: [Color] = []
                    for colorValue in json["colors"].arrayValue {
                        if let color = ScriptWidgetAttributeColor.getColorFromColorValue(colorValue.stringValue) {
                            colors.append(color)
                        } else {
                            colors.append(Color.clear)
                        }
                    }
                    
                    // center
                    let center = ScriptWidgetElementPoint.getPointFromPointValue(json["center"].stringValue)
                    
                    return AnyView(AngularGradient(gradient: Gradient(colors: colors), center: center))
                    
                } else {
                    print("unknown gradient type : \(type)")
                }
                
            } catch {
                print("gradient json parse failed : \(jsonString) ; error = \(error)")
            }
        }
        
        return AnyView(LinearGradient(gradient: Gradient(colors: [.orange, .red]), startPoint: .leading, endPoint: .trailing))
        
    }
    
}



//
//
//struct ScriptWidgetElementGradientSampleView: View {
//    var body: some View {
//        ZStack {
////            LinearGradient(gradient: Gradient(colors: [.blue, .white, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
//
//            RadialGradient(gradient: Gradient(colors: [.orange, .red, .white]), center: .center, startRadius: 100, endRadius: 470)
//
////            AngularGradient(gradient: Gradient(colors: [.green, .blue, .black, .green, .blue, .black, .green]), center: .center)
//
//            Text("SwiftUI").font(.system(size: 83)).fontWeight(.thin).foregroundColor(.white)
//        }.edgesIgnoringSafeArea(.all)
//    }
//}
//struct ScriptWidgetElementGradientSampleView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScriptWidgetElementGradientSampleView()
//    }
//}
