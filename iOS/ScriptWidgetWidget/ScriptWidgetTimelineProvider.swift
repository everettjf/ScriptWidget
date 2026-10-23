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
        let now = Date()
        let offset = (configuration.Frequency ?? .hours_1).refreshOffset
        let fallback = Calendar.current.date(byAdding: offset.component, value: offset.value, to: now) ?? now.addingTimeInterval(3_600)
        let execution = try? ScriptWidgetHostExecution.load(name: configuration.Script ?? "")
        let schedule = execution.flatMap { captured in
            captured.package.readManifest().flatMap {
                WidgetPackageManifestValidator.validate($0, package: captured.package, checkEntryExists: false).isValid ? $0.timeline : nil
            }
        }
        let plan = ScriptWidgetTimelinePlan(schedule: schedule, now: now, fallbackReload: fallback)
        let entries = plan.entries.map {
            ScriptWidgetTimelineEntry(isPreview: false, date: $0.date, configuration: configuration,
                                      timelineEnvironments: $0.environments(timeZone: plan.timeZone))
        }
        return Timeline(entries: entries, policy: .after(plan.reloadAfter))
    }
}

extension AppConfigFrequency {
    /// Calendar offset used to schedule the next widget refresh.
    var refreshOffset: (component: Calendar.Component, value: Int) {
        switch self {
        case .minutes_1:  return (.minute, 1)
        case .minutes_10: return (.minute, 10)
        case .minutes_30: return (.minute, 30)
        case .hours_1:    return (.hour, 1)
        case .hours_3:    return (.hour, 3)
        case .hours_6:    return (.hour, 6)
        case .hours_12:   return (.hour, 12)
        case .day_1:      return (.day, 1)
        }
    }
}

struct ScriptWidgetTimelineEntry: TimelineEntry {
    let isPreview: Bool
    let date: Date
    let configuration: ScriptWidgetAppIntent
    var timelineEnvironments: [String: String] = [:]
}
