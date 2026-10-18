//
//  ScriptWidgetPreviewApp.swift
//  ScriptWidget Preview
//
//  A developer tool that renders the same widget package with the native
//  macOS SwiftUI runtime and with the browser preview engine, side by side,
//  and measures the pixel difference. Run with `--batch <directory>` to
//  compare the whole corpus and write a report.
//

import SwiftUI

@main
struct ScriptWidgetPreviewApp: App {
    @NSApplicationDelegateAdaptor private var delegate: PreviewAppDelegate
    @StateObject private var model = CompareModel()

    var body: some Scene {
        WindowGroup("ScriptWidget Preview") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1480, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Package Folder…") { model.openFolder() }
                    .keyboardShortcut("o")
            }
        }
    }
}

final class PreviewAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--batch"), index + 1 < arguments.count else { return }
        let output = URL(fileURLWithPath: arguments[index + 1])
        let filter = arguments.firstIndex(of: "--filter").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil } ?? ""
        let families = arguments.firstIndex(of: "--families").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }?
            .split(separator: ",").map(String.init) ?? ["small", "medium", "large"]
        Task { @MainActor in
            let code = await BatchComparison.run(output: output, filter: filter, families: families)
            exit(code)
        }
    }
}
