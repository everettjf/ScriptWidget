import AppKit
import SwiftUI

/// Renders a package with the shared runtime exactly like the macOS widget's
/// ScriptWidgetWidgetElementRootView: the root background becomes the
/// container background and the root view is centered in the family size.
@MainActor
enum NativeRenderer {
    struct Result {
        let image: CGImage?
        let error: String?
        let milliseconds: Double
    }

    static func render(source: String, package: ScriptWidgetPackage, family: PreviewFamily, dark: Bool, scale: CGFloat = 2) async -> Result {
        let started = Date()
        let runtime = ScriptWidgetRuntime(package: package, environments: [
            "widget-size": family.rawValue, "widget-param": "", "widget-rendering-mode": "fullColor",
        ])
        let result = await Task.detached { runtime.executeJSXSyncForWidget(source) }.value
        guard let element = result.0 else {
            return Result(image: nil, error: result.1?.displayMessage ?? "No element", milliseconds: Date().timeIntervalSince(started) * 1000)
        }
        let context = ScriptWidgetElementContext(runtime: runtime, debugMode: false, scriptName: package.name, scriptParameter: "",
                                                 package: package, containerBackgroundElement: element)
        let view = NativeWidgetView(element: element, context: context, size: family.size)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        var image: CGImage?
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua) ?? NSAppearance.currentDrawing()
        appearance.performAsCurrentDrawingAppearance { image = renderer.cgImage }
        return Result(image: image, error: image == nil ? "Rendering failed" : nil, milliseconds: Date().timeIntervalSince(started) * 1000)
    }
}

struct NativeWidgetView: View {
    let element: ScriptWidgetRuntimeElement
    let context: ScriptWidgetElementContext
    let size: CGSize

    var body: some View {
        let background = element.getPropString("background").map(ScriptWidgetAttributeColor.init) ?? ScriptWidgetAttributeColor()
        ZStack {
            if let color = background.color { color } else if let gradient = background.gradient { gradient } else { Rectangle().fill(.background) }
            ScriptWidgetElementView(element: element, context: context)
        }
        .frame(width: size.width, height: size.height)
    }
}
