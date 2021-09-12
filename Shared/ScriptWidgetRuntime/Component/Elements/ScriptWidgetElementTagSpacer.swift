//
//  ScriptWidgetElementTagSpacer.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI

class ScriptWidgetElementTagSpacer {
    static func buildView(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) -> AnyView {
        return AnyView(
            Spacer()
        )
    }
}
