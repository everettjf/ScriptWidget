//
//  ScriptWidgetControlAppIntent.swift
//  ScriptWidget
//
//  Created by eevv on 11/5/24.
//
import SwiftUI
import WidgetKit
import AppIntents


struct ScriptWidgetControlAppIntent: AppIntent {
  static var title: LocalizedStringResource = "ScriptWidget control app intent"
  static var description = IntentDescription("ScriptWidget control app intent description")

  init() {
  }

  func perform() async throws -> some IntentResult {
    print("ScriptWidget control app intent performed")
    return .result()
  }
}
