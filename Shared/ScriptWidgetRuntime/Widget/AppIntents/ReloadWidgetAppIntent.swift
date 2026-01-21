//
//  ReloadWidgetAppIntent.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import AppIntents
import WidgetKit

struct ReloadWidgetAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh ScriptWidget"
    static var description = IntentDescription("Refresh ScriptWidget timelines.")

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "ScriptWidget")
        return .result()
    }
}
