//
//  ScriptWidgetControlWidget.swift
//  ScriptWidgetWidget

import Foundation
import SwiftUI
import WidgetKit

struct ScriptWidgetControlWidget: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "ScriptWidget") {
      ControlWidgetButton(action: ScriptWidgetControlAppIntent()) {
        Label("Click Script Widget", systemImage: "gamecontroller")
      }
    }
  }
}
