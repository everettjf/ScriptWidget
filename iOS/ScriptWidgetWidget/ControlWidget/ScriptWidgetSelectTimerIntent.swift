import AppIntents
import Foundation
import WidgetKit

private enum ScriptWidgetControlCatalog {
    static func controls(type: WidgetPackageControlType) -> [(ResolvedScriptWidgetAction, WidgetPackageControl)] {
        ScriptWidgetActionCatalog.live.controls(type: type)
    }

    static func resolve(id: String, type: WidgetPackageControlType) -> (ResolvedScriptWidgetAction, WidgetPackageControl)? {
        ScriptWidgetActionCatalog.live.resolveControl(identifier: id, type: type)
    }

    static func entityID(resolved: ResolvedScriptWidgetAction, control: WidgetPackageControl) -> String {
        ScriptWidgetActionCatalog.controlIdentifier(resolved, control)
    }

    static func storageValue(resolved: ResolvedScriptWidgetAction, key: String) -> Bool {
        (try? ScriptWidgetActionExecutor.toggleValue(resolved: resolved, stateKey: key)) ?? false
    }

}

struct ScriptWidgetButtonControlEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Button"
    static var defaultQuery = ScriptWidgetButtonControlQuery()

    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: subtitle.map { "\($0)" })
    }
}

struct ScriptWidgetButtonControlQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ScriptWidgetButtonControlEntity] {
        identifiers.compactMap { id in
            guard let (resolved, control) = ScriptWidgetControlCatalog.resolve(id: id, type: .button) else { return nil }
            return .init(
                id: id,
                title: control.title,
                subtitle: resolved.controlSubtitle(control),
                systemImage: control.systemImage
            )
        }
    }

    func suggestedEntities() async throws -> [ScriptWidgetButtonControlEntity] {
        ScriptWidgetControlCatalog.controls(type: .button).map { resolved, control in
            .init(
                id: ScriptWidgetControlCatalog.entityID(resolved: resolved, control: control),
                title: control.title,
                subtitle: resolved.controlSubtitle(control),
                systemImage: control.systemImage
            )
        }
    }
}

struct ScriptWidgetToggleControlEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Toggle"
    static var defaultQuery = ScriptWidgetToggleControlQuery()

    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: subtitle.map { "\($0)" })
    }
}

struct ScriptWidgetToggleControlQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ScriptWidgetToggleControlEntity] {
        identifiers.compactMap { id in
            guard let (resolved, control) = ScriptWidgetControlCatalog.resolve(id: id, type: .toggle) else { return nil }
            return .init(id: id, title: control.title, subtitle: resolved.controlSubtitle(control), systemImage: control.systemImage)
        }
    }

    func suggestedEntities() async throws -> [ScriptWidgetToggleControlEntity] {
        ScriptWidgetControlCatalog.controls(type: .toggle).map { resolved, control in
            .init(
                id: ScriptWidgetControlCatalog.entityID(resolved: resolved, control: control),
                title: control.title,
                subtitle: resolved.controlSubtitle(control),
                systemImage: control.systemImage
            )
        }
    }
}

struct SelectScriptWidgetButtonIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget Button"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Button") var control: ScriptWidgetButtonControlEntity?

    init() {}
}

struct SelectScriptWidgetToggleIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Select Widget Toggle"
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Toggle") var control: ScriptWidgetToggleControlEntity?

    init() {}
}

struct ScriptWidgetButtonControlValue {
    let id: String
    let title: String
    let systemImage: String
}

struct ScriptWidgetToggleControlValue {
    let id: String
    let title: String
    let systemImage: String
    let isOn: Bool
}

struct ScriptWidgetButtonControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: SelectScriptWidgetButtonIntent) -> ScriptWidgetButtonControlValue {
        let control = configuration.control
        return .init(id: control?.id ?? "", title: control?.title ?? "ScriptWidget", systemImage: control?.systemImage ?? "play.fill")
    }

    func currentValue(configuration: SelectScriptWidgetButtonIntent) async throws -> ScriptWidgetButtonControlValue {
        previewValue(configuration: configuration)
    }
}

struct ScriptWidgetToggleControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: SelectScriptWidgetToggleIntent) -> ScriptWidgetToggleControlValue {
        let control = configuration.control
        return .init(id: control?.id ?? "", title: control?.title ?? "ScriptWidget", systemImage: control?.systemImage ?? "switch.2", isOn: false)
    }

    func currentValue(configuration: SelectScriptWidgetToggleIntent) async throws -> ScriptWidgetToggleControlValue {
        let preview = previewValue(configuration: configuration)
        guard let (resolved, control) = ScriptWidgetControlCatalog.resolve(id: preview.id, type: .toggle),
              let stateKey = control.stateKey else { return preview }
        return .init(
            id: preview.id,
            title: control.title,
            systemImage: control.systemImage,
            isOn: ScriptWidgetControlCatalog.storageValue(resolved: resolved, key: stateKey)
        )
    }
}

struct RunScriptWidgetControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Widget Control"
    static var isDiscoverable: Bool { false }
    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .widgetKitExtension }
    #endif

    @Parameter(title: "Control ID") var controlID: String

    init() {}
    init(controlID: String) { self.controlID = controlID }

    func perform() async throws -> some IntentResult {
        guard let (resolved, control) = ScriptWidgetActionCatalog.live.resolveControl(identifier: controlID, type: .button) else {
            throw ScriptWidgetActionExecutionError.actionNotFound
        }
        let result = ScriptWidgetActionExecutor(catalog: .live).execute(
            resolved: resolved,
            source: .control,
            contextID: control.id
        )
        if case .failure(let error) = result { throw error }
        ControlCenter.shared.reloadControls(ofKind: "ScriptWidget.Button")
        return .result()
    }
}

struct SetScriptWidgetControlValueIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Set Widget Control Value"
    static var isDiscoverable: Bool { false }
    #if compiler(>=6.4)
    @available(iOS 27.0, *)
    static var allowedExecutionTargets: ExecutionTargets { .widgetKitExtension }
    #endif

    @Parameter(title: "Enabled") var value: Bool
    @Parameter(title: "Control ID") var controlID: String

    init() {}
    init(controlID: String) { self.controlID = controlID }

    func perform() async throws -> some IntentResult {
        guard let (resolved, control) = ScriptWidgetActionCatalog.live.resolveControl(identifier: controlID, type: .toggle),
              let stateKey = control.stateKey else { return .result() }
        let result = ScriptWidgetActionExecutor(catalog: .live).setToggleValue(
            value,
            resolved: resolved,
            stateKey: stateKey,
            source: .control,
            contextID: control.id
        )
        if case .failure(let error) = result { throw error }
        ControlCenter.shared.reloadControls(ofKind: "ScriptWidget.Toggle")
        WidgetCenter.shared.reloadTimelines(ofKind: "ScriptWidget")
        return .result()
    }
}
