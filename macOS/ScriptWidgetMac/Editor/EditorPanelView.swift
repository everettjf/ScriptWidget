//
//  EditorPanelView.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/2/4.
//

import SwiftUI

struct EditorPanelTabLabel: View {
    let imageName: String
    let label: String
    
    var body: some View {
        HStack {
            Image(systemName: imageName)
            Text(label)
        }
    }
}



struct EditorPanelView: View {
    let scriptModel: ScriptModel
    
    var body: some View {
        TabView {
            VStack {
                PreviewView(scriptModel: scriptModel)
            }
            .tabItem({ EditorPanelTabLabel(imageName: "house.fill", label: "Preview") })
            
            VStack {
                ImageListView(scriptModel: scriptModel)
            }
            .tabItem({ EditorPanelTabLabel(imageName: "magnifyingglass", label: "Images") })
            
            VStack {
                FileListView(scriptModel: scriptModel)
            }
            .tabItem({ EditorPanelTabLabel(imageName: "filemenu.and.cursorarrow", label: "Files") })
        }
    }
}

struct EditorPanelView_Previews: PreviewProvider {
    static var previews: some View {
        EditorPanelView(scriptModel: globalScriptModel)
    }
}
