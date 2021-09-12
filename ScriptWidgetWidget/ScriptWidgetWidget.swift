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

struct Provider: IntentTimelineProvider {
        
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(isPreview: true, date: Date(), configuration: ScriptIntent())
    }

    func getSnapshot(for configuration: ScriptIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(isPreview: context.isPreview, date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ScriptIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []


        if configuration.Frequency == .miniutes_10 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .minute, value: 10, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .miniutes_30 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .hours_1 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .hours_3 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 3, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .hours_6 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 6, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .hours_12 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 12, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else if configuration.Frequency == .day_1 {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        } else {
            let currentDate = Date()
            let entryDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
            let entry = SimpleEntry(isPreview: false, date: entryDate, configuration: configuration)
            entries.append(entry)
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
        
    }
}

struct SimpleEntry: TimelineEntry {
    let isPreview: Bool
    let date: Date
    let configuration: ScriptIntent
}


class ScriptWidgetDataObject : ObservableObject {
    let scriptName: String
    let widgetFamily: WidgetFamily
    
    @Published var rootElement : ScriptWidgetRuntimeElement
    
    var cancellables: [AnyCancellable] = []
    
    init(scriptName: String, widgetFamily: WidgetFamily) {
        self.scriptName = scriptName
        self.widgetFamily = widgetFamily
        
        self.rootElement = ScriptWidgetRuntimeElement(tag: "text", props: nil, children: ["."])
    }
    
    deinit {
        for item in cancellables {
            item.cancel()
        }
    }
    
    func createTextElement(info: String) -> ScriptWidgetRuntimeElement {
        return ScriptWidgetRuntimeElement(tag: "text", props: nil, children: [info])
    }
    
    func runScriptSync() {
        if self.scriptName.count == 0 {
            self.rootElement = createTextElement(info: "No script selected")
            return
        }
        
        self.systemLog("[START]")
        
        let script = sharedScriptManager.getScript(scriptId: self.scriptName)
        
        guard let JSX = script.file.readFile() else {
            self.rootElement = createTextElement(info: "Failed open script")
            return
        }
        
        var widgetSizeString = ""
        switch self.widgetFamily {
        case .systemLarge: widgetSizeString = "large"
        case .systemMedium: widgetSizeString = "medium"
        case .systemSmall: widgetSizeString = "small"
        default: widgetSizeString = "small"
        }
        let runtime = ScriptWidgetRuntime(environments: [
            "widget-size" : widgetSizeString
        ])
        
        let result = runtime.executeJSXSync(JSX)
        
        if let element = result.0 {
            // succeed
            self.rootElement = element
        } else {
            // error
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

struct ScriptWidgetWidgetEntryView : View {
    @Environment(\.widgetFamily) var family: WidgetFamily
    
    @ObservedObject var data = ScriptWidgetDataObject(scriptName: "", widgetFamily: .systemSmall)

    var entry: Provider.Entry
    
    init(entry: Provider.Entry) {
        self.entry = entry
        self.data = ScriptWidgetDataObject(scriptName: entry.configuration.Script ?? "", widgetFamily: self.family)
        self.data.runScriptSync()
    }

    @ViewBuilder
    var body: some View {
        if self.entry.isPreview {
            ScriptWidgetPlaceholderView()
        } else {
            ScriptWidgetElementView(element: data.rootElement, context: ScriptWidgetElementContext(debugMode: false))
        }
    }
}


struct ScriptWidgetWidget: Widget {
    let kind: String = "ScriptWidgetWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ScriptIntent.self, provider: Provider()) { entry in
            ScriptWidgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ScriptWidget")
        .description("Build your own widgets")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
    
    init() {
        let _ = globalState
    }
}

struct ScriptWidgetWidget_Previews: PreviewProvider {
    static var previews: some View {
        let entry = SimpleEntry(isPreview:false ,date: Date(), configuration: ScriptIntent())
        
        ScriptWidgetWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        ScriptWidgetWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        ScriptWidgetWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}

@main
struct ScriptWidgets: WidgetBundle {
    var body: some Widget {
        ScriptWidgetWidget()
    }
}
