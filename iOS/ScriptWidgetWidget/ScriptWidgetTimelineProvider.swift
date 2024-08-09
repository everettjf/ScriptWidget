//
//  ScriptWidgetTimelineProvider.swift
//  ScriptWidgetWidget
//
//  Created by zhufeng on 2023/10/7.
//

import Foundation
import WidgetKit
import SwiftUI
import Intents
import Combine

struct ScriptWidgetTimelineProvider: AppIntentTimelineProvider {
  
    func placeholder(in context: Context) -> ScriptWidgetTimelineEntry {
        ScriptWidgetTimelineEntry(isPreview: true, date: Date(), configuration: ScriptWidgetAppIntent())
    }
    
    func snapshot(for configuration: ScriptWidgetAppIntent, in context: Context) async -> ScriptWidgetTimelineEntry {
        let entry = ScriptWidgetTimelineEntry(isPreview: context.isPreview, date: Date(), configuration: configuration)
        return entry
    }

    func timeline(for configuration: ScriptWidgetAppIntent, in context: Context) async -> Timeline<ScriptWidgetTimelineEntry> {
        var entries: [ScriptWidgetTimelineEntry] = []
        if configuration.Frequency == .minutes_1 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .minutes_10 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .minutes_30 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .hours_1 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .hours_3 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 3, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .hours_6 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 6, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .hours_12 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else if configuration.Frequency == .day_1 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        } else {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let entry = ScriptWidgetTimelineEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            return timeline
        }
    }
}

struct ScriptWidgetTimelineEntry: TimelineEntry {
    let isPreview: Bool
    let date: Date
    let configuration: ScriptWidgetAppIntent
}
