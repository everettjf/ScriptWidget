//
//  SidebarWidgetRowView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/15.
//

import SwiftUI


struct WidgetRowImageView: View {
    var model: ScriptModel
    
    var body: some View {
        NameAutoImageView(name: model.name, colors: getGradientColorsWithString(string: model.name), size: 20)
    }
}

struct WidgetRowTextView: View {
    var model: ScriptModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.name)
        }
        .frame(height:20)
    }
}


struct WidgetRowView: View {
    
    var model: ScriptModel
    
    var body: some View {
        HStack {
            WidgetRowImageView(model: model)
            WidgetRowTextView(model: model)
        }
    }
}

struct WidgetRowView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetRowView(model: ScriptModel(package: ScriptWidgetPackage(bundle: "Script", relativePath: "template/is-friday")))
            .previewLayout(.sizeThatFits)
            .padding()
        
        
        WidgetRowView(model: ScriptModel(package: ScriptWidgetPackage(bundle: "Script", relativePath: "template/is-friday")))
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
        
    }
}
