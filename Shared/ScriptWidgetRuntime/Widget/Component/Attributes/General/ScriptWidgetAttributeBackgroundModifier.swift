//
//  ScriptWidgetAttributeBackgroundModifier.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/18.
//

import Foundation
import SwiftUI
import WidgetKit

/// Trusted host preview overrides. Scripts cannot change SwiftUI environment
/// values; nil uses the real OS accessibility setting. Public EnvironmentKey
/// avoids touching Apple's read-only/private accessibility environment setters.
struct ScriptWidgetVisualAccessibility: Sendable {
    var reduceTransparency: Bool? = nil
    var reduceMotion: Bool? = nil
}
private struct ScriptWidgetVisualAccessibilityKey: EnvironmentKey {
    static let defaultValue = ScriptWidgetVisualAccessibility()
}
extension EnvironmentValues {
    var scriptWidgetVisualAccessibility: ScriptWidgetVisualAccessibility {
        get { self[ScriptWidgetVisualAccessibilityKey.self] }
        set { self[ScriptWidgetVisualAccessibilityKey.self] = newValue }
    }
}

enum ScriptWidgetBackgroundMaterial: String, CaseIterable {
    case ultraThin, thin, regular, thick, ultraThick

    var material: Material {
        switch self {
        case .ultraThin: return .ultraThin
        case .thin: return .thin
        case .regular: return .regular
        case .thick: return .thick
        case .ultraThick: return .ultraThick
        }
    }

    static func isEnabled(_ value: String?) -> Bool {
        value.flatMap(Self.init(rawValue:)) != nil
    }

    static func usesMaterial(reduceTransparency: Bool, renderingMode: WidgetRenderingMode) -> Bool {
        !reduceTransparency && renderingMode == .fullColor
    }
}

/// Material blurs content inside the widget, never the Home Screen wallpaper.
/// In reduced transparency the authored background is composited over an opaque
/// base. Tinted/vibrant modes omit the local material so system colors stay legible.
private struct ScriptWidgetMaterialBackground: View {
    let style: ScriptWidgetBackgroundMaterial
    let fallback: ScriptWidgetAttributeColor
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scriptWidgetVisualAccessibility) private var preview

    @ViewBuilder var body: some View {
        if renderingMode != .fullColor {
            Color.clear
        } else if ScriptWidgetBackgroundMaterial.usesMaterial(reduceTransparency: preview.reduceTransparency ?? reduceTransparency, renderingMode: renderingMode) {
            Rectangle().fill(style.material)
        } else {
            ZStack {
                colorScheme == .dark ? Color.black : Color.white
                if let color = fallback.color { color }
                else if let gradient = fallback.gradient { gradient }
            }
        }
    }
}


struct ScriptWidgetAttributeBackgroundModifier: ViewModifier {
    
    let color: ScriptWidgetAttributeColor
    let usesContainerBackground: Bool
    let material: ScriptWidgetBackgroundMaterial?
    
    init(_ element: ScriptWidgetRuntimeElement, _ context: ScriptWidgetElementContext) {
        usesContainerBackground = context.usesContainerBackground(for: element)
        material = element.getPropString("backgroundMaterial").flatMap(ScriptWidgetBackgroundMaterial.init(rawValue:))
        if let backgroundValue = element.getPropString("background")  {
            color = ScriptWidgetAttributeColor(backgroundValue)
        } else {
            color = ScriptWidgetAttributeColor()
        }
    }
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if usesContainerBackground {
            content
        } else if let material {
            content.background { ScriptWidgetMaterialBackground(style: material, fallback: color) }
        } else if let backgroundColor = self.color.color {
            content.background(backgroundColor)
        } else if let gradient = self.color.gradient {
            content.background(gradient)
        } else {
            content
        }
    }
    
}

struct ScriptWidgetContainerBackgroundModifier: ViewModifier {
    let background: ScriptWidgetAttributeColor
    let material: ScriptWidgetBackgroundMaterial?

    init(_ element: ScriptWidgetRuntimeElement) {
        material = element.getPropString("backgroundMaterial").flatMap(ScriptWidgetBackgroundMaterial.init(rawValue:))
        if let backgroundValue = element.getPropString("background") {
            background = ScriptWidgetAttributeColor(backgroundValue)
        } else {
            background = ScriptWidgetAttributeColor()
        }
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            if let material {
                content.containerBackground(for: .widget) { ScriptWidgetMaterialBackground(style: material, fallback: background) }
            } else if let backgroundColor = background.color {
                content.containerBackground(for: .widget) {
                    backgroundColor
                }
            } else if let gradient = background.gradient {
                content.containerBackground(for: .widget) {
                    gradient
                }
            } else {
                content.containerBackground(.background, for: .widget)
            }
        } else if let material {
            content.background { ScriptWidgetMaterialBackground(style: material, fallback: background) }
        } else if let backgroundColor = background.color {
            content.background(backgroundColor)
        } else if let gradient = background.gradient {
            content.background(gradient)
        } else {
            content
        }
    }
}
