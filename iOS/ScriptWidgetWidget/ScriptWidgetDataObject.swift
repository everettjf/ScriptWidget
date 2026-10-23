//
//  ScriptWidgetDataObject.swift
//  ScriptWidgetWidget
//
//  Created by everettjf on 2022/9/17.
//

import Foundation
import SwiftUI
import Combine
import WidgetKit

class ScriptWidgetDataObject : ObservableObject {
    let scriptName: String
    let scriptParameter: String
    let widgetFamily: WidgetFamily
    private(set) var package: ScriptWidgetPackage = globalScriptWidgetPackage
    
    @Published var rootElement : ScriptWidgetRuntimeElement
    var runtime: ScriptWidgetRuntime?
    
    var cancellables: [AnyCancellable] = []
    
    let widgetRenderingMode: String
    let timelineEnvironments: [String: String]
    let isDarkMode: Bool?

    init(scriptName: String, scriptParameter: String, widgetFamily: WidgetFamily, widgetRenderingMode: String = "fullColor", timelineEnvironments: [String: String] = [:], isDarkMode: Bool? = nil) {
        self.scriptName = scriptName
        self.scriptParameter = scriptParameter
        self.widgetFamily = widgetFamily
        self.widgetRenderingMode = widgetRenderingMode
        self.timelineEnvironments = timelineEnvironments
        self.isDarkMode = isDarkMode
        
        
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

        let standardWidgetSizeString: String = {
            switch self.widgetFamily {
            case .systemLarge: return "large"
            case .systemMedium: return "medium"
            case .systemSmall: return "small"
            case .systemExtraLarge: return "extraLarge"
            case .accessoryInline: return "accessoryInline"
            case .accessoryCircular: return "accessoryCircular"
            case .accessoryRectangular: return "accessoryRectangular"
            default: return "small"
            }
        }()
        let widgetSizeString: String
        #if compiler(>=6.4)
            if #available(iOSApplicationExtension 27.0, *), self.widgetFamily == .systemExtraLargePortrait {
                widgetSizeString = "extraLargePortrait"
            } else {
                widgetSizeString = standardWidgetSizeString
            }
        #else
            widgetSizeString = standardWidgetSizeString
        #endif
        let runtime = ScriptWidgetRuntime(package: self.package, environments: [
            "widget-size" : widgetSizeString,
            "widget-param": scriptParameter,
            "widget-rendering-mode": widgetRenderingMode,
        ].merging(timelineEnvironments) { _, planned in planned }, executionSnapshot: execution.snapshot, isDarkMode: isDarkMode)
        
        let result = runtime.executeJSXSyncForWidget(JSX)
        
        if let element = result.0 {
            // succeed
            self.rootElement = element
            self.runtime = runtime
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
