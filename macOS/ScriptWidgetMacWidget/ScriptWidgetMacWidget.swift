//
//  ScriptWidgetMacWidget.swift
//  ScriptWidgetMacWidget
//
//  Created by everettjf on 2022/1/14.
//

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

class ScriptWidgetDataObject : ObservableObject {
    let scriptName: String
    let scriptParameter: String
    let widgetFamily: WidgetFamily
    let widgetRenderingMode: String
    let timelineEnvironments: [String: String]
    let isDarkMode: Bool?
    private(set) var package: ScriptWidgetPackage = globalScriptWidgetPackage
    
    @Published var rootElement : ScriptWidgetRuntimeElement
    
    var runtime: ScriptWidgetRuntime?
    
    var cancellables: [AnyCancellable] = []
    
    init(scriptName: String, scriptParameter: String, widgetFamily: WidgetFamily, widgetRenderingMode: String = "fullColor", timelineEnvironments: [String: String] = [:], isDarkMode: Bool? = nil) {
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        self.widgetFamily = widgetFamily
        self.widgetRenderingMode = widgetRenderingMode
        self.timelineEnvironments = timelineEnvironments
        self.isDarkMode = isDarkMode
        self.runtime = nil
        
        self.rootElement = ScriptWidgetRuntimeElement(tagString: "text", props: nil, children: ["."])
    }
    
    deinit {
        for item in cancellables {
            item.cancel()
        }
    }
    
    func createTextElement(info: String) -> ScriptWidgetRuntimeElement {
        return ScriptWidgetRuntimeElement(tagString: "text", props: nil, children: [info])
    }
    
    func runScriptSync() {
        if self.scriptName.count == 0 {
            self.rootElement = createTextElement(info: "No script selected")
            return
        }
        
        self.systemLog("[START]")
        
        self.runtime = nil
        let execution: ScriptWidgetHostExecution
        do {
            execution = try ScriptWidgetHostExecution.load(name: scriptName, cacheOnly: false)
            self.package = execution.package
        } catch {
            let message = (error as? ScriptWidgetHostReadError)?.message
                ?? "Widget library unavailable. Open ScriptWidget to finish opening or migrating the library."
            self.rootElement = createTextElement(info: message)
            return
        }
        let JSX = execution.source

        let standardWidgetSizeString: String
        switch self.widgetFamily {
        case .systemLarge: standardWidgetSizeString = "large"
        case .systemMedium: standardWidgetSizeString = "medium"
        case .systemSmall: standardWidgetSizeString = "small"
        case .systemExtraLarge: standardWidgetSizeString = "extraLarge"
        default: standardWidgetSizeString = "small"
        }
        let widgetSizeString: String
        #if compiler(>=6.4)
            if #available(macOSApplicationExtension 27.0, *), self.widgetFamily == .systemExtraLargePortrait {
                widgetSizeString = "extraLargePortrait"
            } else {
                widgetSizeString = standardWidgetSizeString
            }
        #else
            widgetSizeString = standardWidgetSizeString
        #endif
        let runtime = ScriptWidgetRuntime(package:self.package, environments: [
            "widget-size" : widgetSizeString,
            "widget-param": self.scriptParameter,
            "widget-rendering-mode": widgetRenderingMode,
        ].merging(timelineEnvironments) { _, planned in planned }, executionSnapshot: execution.snapshot, isDarkMode: isDarkMode)
        
        let result = runtime.executeJSXSyncForWidget(JSX)
        
        if let element = result.0 {
            // succeed
            self.runtime = runtime
            self.rootElement = element
        } else {
            // error
            self.runtime = nil

            if let error = result.1 {
                let message = error.displayMessage
                self.systemLog(message)
                self.rootElement = createTextElement(info: message)
            }
        }

        self.systemLog("[FINISH]")
    }

    func systemLog(_ str: String) {
        SWLog.info(str)
    }
}

struct ScriptWidgetWidgetElementRootView: View {
    private let data: ScriptWidgetDataObject
    let widgetFamily: WidgetFamily

    init(widgetFamily: WidgetFamily, renderingMode: WidgetRenderingMode, colorScheme: ColorScheme, entry: ScriptWidgetTimelineEntry) {
        self.widgetFamily = widgetFamily
        let data = ScriptWidgetDataObject(
            scriptName: entry.configuration.Script ?? "",
            scriptParameter: entry.configuration.Parameter ?? "",
            widgetFamily: self.widgetFamily,
            widgetRenderingMode: renderingMode == .accented ? "accented" : (renderingMode == .vibrant ? "vibrant" : "fullColor"),
            timelineEnvironments: entry.timelineEnvironments,
            isDarkMode: colorScheme == .dark
        )
        data.runScriptSync()
        self.data = data
    }
    
    @ViewBuilder
    var body: some View {
        ScriptWidgetElementView(
            element: data.rootElement,
            context: ScriptWidgetElementContext(
                runtime: data.runtime,
                debugMode: false,
                scriptName: data.scriptName,
                scriptParameter: data.scriptParameter,
                package: data.package,
                containerBackgroundElement: data.rootElement
            )
        )
        .modifier(ScriptWidgetContainerBackgroundModifier(data.rootElement))
    }
}

struct ScriptWidgetMacWidgetEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    var entry: ScriptWidgetTimelineEntry
    
    init(entry: ScriptWidgetTimelineEntry) {
        self.entry = entry
    }
    var body: some View {
        if self.entry.isPreview {
            ScriptWidgetPlaceholderView()
                .containerBackground(.background, for: .widget)
        } else {
            ScriptWidgetWidgetElementRootView(widgetFamily: self.widgetFamily, renderingMode: widgetRenderingMode, colorScheme: colorScheme, entry: self.entry)
        }
    }
}

@main
struct ScriptWidgetMacWidget: Widget {
    let kind: String = "ScriptWidgetMacWidget"

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
        ]
        #if compiler(>=6.4)
            if #available(macOSApplicationExtension 27.0, *) {
                families.append(.systemExtraLargePortrait)
            }
        #endif
        return families
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ScriptWidgetAppIntent.self, provider: ScriptWidgetTimelineProvider()) { entry in
            ScriptWidgetMacWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ScriptWidget")
        .description("Build your own widgets")
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
    }
}

struct ScriptWidgetMacWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = ScriptWidgetTimelineEntry( isPreview: false , date: Date(), configuration: ScriptWidgetAppIntent())
        ScriptWidgetMacWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        ScriptWidgetMacWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        ScriptWidgetMacWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}
