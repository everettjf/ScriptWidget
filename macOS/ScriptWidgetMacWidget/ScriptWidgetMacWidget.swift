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

class ScriptWidgetDataObject : ObservableObject {
    let scriptName: String
    let scriptParameter: String
    let widgetFamily: WidgetFamily
    let package: ScriptWidgetPackage
    
    @Published var rootElement : ScriptWidgetRuntimeElement
    
    var runtime: ScriptWidgetRuntime?
    
    var cancellables: [AnyCancellable] = []
    
    init(scriptName: String, scriptParameter: String, widgetFamily: WidgetFamily) {
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        self.widgetFamily = widgetFamily
        self.runtime = nil
        self.package = sharedScriptManager.getScriptPackage(packageName: self.scriptName)
        
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
        
        let mainFile = self.package.readMainFile()
        guard let JSX = mainFile.0 else {
            self.rootElement = createTextElement(info: "Failed open script : \(mainFile.1)")
            return
        }
        
        var widgetSizeString = ""
        switch self.widgetFamily {
        case .systemLarge: widgetSizeString = "large"
        case .systemMedium: widgetSizeString = "medium"
        case .systemSmall: widgetSizeString = "small"
        default: widgetSizeString = "small"
        }
        let runtime = ScriptWidgetRuntime(package:self.package, environments: [
            "widget-size" : widgetSizeString,
            "widget-param": self.scriptParameter,
        ])
        
        let result = runtime.executeJSXSyncForWidget(JSX)
        
        if let element = result.0 {
            // succeed
            self.runtime = runtime
            self.rootElement = element
        } else {
            // error
            self.runtime = nil
            
            if let error = result.1 {
                switch error {
                case .undefinedRender(let msg):
                    self.systemLog(msg)
                case .internalError(let msg):
                    self.systemLog(msg)
                case .scriptError(let msg):
                    self.systemLog(msg)
                case .scriptException(let msg):
                    self.systemLog(msg)
                case .transformError(let msg):
                    self.systemLog(msg)
                }
            }
        }
        
        self.systemLog("[FINISH]")
    }
    
    func systemLog(_ str: String) {
        print("system log: \(str)")
    }
}

struct ScriptWidgetWidgetElementRootView: View {
    @ObservedObject var data = ScriptWidgetDataObject(scriptName: "", scriptParameter: "", widgetFamily: .systemSmall)
    var widgetFamily: WidgetFamily

    init(widgetFamily: WidgetFamily, entry: ScriptWidgetTimelineEntry) {
        self.widgetFamily = widgetFamily
        self.data = ScriptWidgetDataObject(
            scriptName: entry.configuration.Script ?? "",
            scriptParameter: entry.configuration.Parameter ?? "",
            widgetFamily: self.widgetFamily
        )
        self.data.runScriptSync()
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
                package: data.package
            )
        )
    }
}

struct ScriptWidgetMacWidgetEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: ScriptWidgetTimelineEntry
    
    init(entry: ScriptWidgetTimelineEntry) {
        self.entry = entry
    }
    var body: some View {
        if self.entry.isPreview {
            ScriptWidgetPlaceholderView()
        } else {
            ScriptWidgetWidgetElementRootView(widgetFamily: self.widgetFamily, entry: self.entry)
        }
    }
}

@main
struct ScriptWidgetMacWidget: Widget {
    let kind: String = "ScriptWidgetMacWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ScriptWidgetAppIntent.self, provider: ScriptWidgetTimelineProvider()) { entry in
            ScriptWidgetMacWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ScriptWidget")
        .description("Build your own widgets")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
