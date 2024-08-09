//
//  ScriptWidgetWidget.swift
//  ScriptWidgetWidget
//
//  Created by everettjf on 2020/10/4.
//

import WidgetKit
import SwiftUI
import Intents
import Combine

struct ScriptWidgetMainWidget: Widget {
    let kind: String = "ScriptWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ScriptWidgetAppIntent.self, provider: ScriptWidgetTimelineProvider()) { entry in
            ScriptWidgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ScriptWidget")
        .description("Build widgets with JavaScript")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .systemExtraLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular,
        ])
        .contentMarginsDisabled()
    }
    
    init() {
        let _ = sharedAppState
    }
}

@main
struct ScriptWidgets: WidgetBundle {
    var body: some Widget {
        ScriptWidgetMainWidget()
        ScriptLiveActivityWidget()
    }
}
