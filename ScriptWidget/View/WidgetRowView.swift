//
//  WidgetRowView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/6.
//

import SwiftUI


struct WidgetRowImageView: View {
    var model: ScriptModel
    
    var body: some View {
        NameAutoImageView(name: model.name, colors: getGradientColorsWithString(string: model.name), size: 45)
        
    }
}

struct WidgetRowTextView: View {
    var model: ScriptModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.name)
                .font(.title3)
                .fontWeight(.bold)
        }
        .frame(height:45)
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
        WidgetRowView(model: ScriptModel(name: "hello-world",  file: ScriptWidgetFile(bundle: "Script", relativePath: "template/is-friday.jsx")))
            .previewLayout(.sizeThatFits)
            .padding()
        
        
        WidgetRowView(model: ScriptModel(name: "hello-world", file: ScriptWidgetFile(bundle: "Script", relativePath: "template/is-friday.jsx")))
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
        
    }
}
