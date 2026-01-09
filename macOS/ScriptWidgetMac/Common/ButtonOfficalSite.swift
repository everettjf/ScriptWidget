//
//  ButtonOfficalSite.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/24.
//

import SwiftUI

struct ButtonOfficalSite: View {
    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(URL(string: "https://xnu.app/scriptwidget")!)
        }) {
            Image(systemName: "questionmark.circle")
        }
    }
}

struct ButtonOfficalSite_Previews: PreviewProvider {
    static var previews: some View {
        ButtonOfficalSite()
    }
}
