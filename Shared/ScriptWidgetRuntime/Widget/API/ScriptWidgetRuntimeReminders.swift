import Foundation
import CoreFoundation
import JavaScriptCore
import CryptoKit
import EventKit

@objc protocol ScriptWidgetRuntimeRemindersExports: JSExport {
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func requestAuthorization() -> ScriptWidgetRuntimePromise
    static func lists() -> ScriptWidgetRuntimePromise
    static func items(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
}

struct ScriptWidgetRemindersQuery {
    let window: ScriptWidgetCalendarQuery
    let completed: Bool
    let timeZone: TimeZone
    init(_ options: [String: Any]?, now: Date = Date(), calendar: Calendar = .current) throws {
        timeZone = calendar.timeZone
        var options = options ?? [:]
        guard Set(options.keys).isSubset(of: ["start", "end", "limit", "listIDs", "maxAgeSeconds", "completed"]) else { throw ScriptWidgetRemindersError.invalid("Unknown reminder query option") }
        if let value = options.removeValue(forKey: "completed") {
            guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { throw ScriptWidgetRemindersError.invalid("completed must be a Boolean") }
            completed = number.boolValue
        } else { completed = false }
        if let ids = options.removeValue(forKey: "listIDs") { options["calendarIDs"] = ids }
        do { window = try ScriptWidgetCalendarQuery(options, now: now, calendar: calendar) }
        catch { throw ScriptWidgetRemindersError.invalid(error.localizedDescription.replacingOccurrences(of: "calendarIDs", with: "listIDs").replacingOccurrences(of: "Calendar", with: "Reminder")) }
    }
    var identity: String { SHA256.hash(data: Data((window.cacheIdentity + (completed ? ":completed:" : ":pending:") + timeZone.identifier).utf8)).map { String(format: "%02x", $0) }.joined() }
}

enum ScriptWidgetRemindersError: LocalizedError {
    case invalid(String), denied, noneSelected, unavailable, queryFailed, scopeChanged
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message.hasPrefix("[invalid_options]") ? message : "[invalid_options] " + message
        case .denied: return "[permission_denied] Allow Reminders access and select lists in ScriptWidget Settings"
        case .noneSelected: return "[permission_denied] No Reminder lists are selected in ScriptWidget Settings"
        case .unavailable: return "[unavailable] Reminder lists are unavailable"
        case .queryFailed: return "[query_failed] Reminders could not be loaded"
        case .scopeChanged: return "[permission_denied] Reminder list selection changed. Run the widget again."
        }
    }
}

struct ScriptWidgetReminderItem: Sendable {
    let id: String
    let listID: String
    let title: String
    let due: String?
    let hasTime: Bool
    let completed: Bool
    let completedAt: String?
    let priority: Int
    var dictionary: [String: Any] {
        ["id": id, "listID": listID, "title": title, "due": due as Any? ?? NSNull(), "hasTime": hasTime,
         "completed": completed, "completedAt": completedAt as Any? ?? NSNull(), "priority": priority]
    }
    static func isoDate(_ text: String) -> Date? {
        guard text.utf8.count <= 64, text.contains("T") else { return nil }
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ISO8601DateFormatter().date(from: text) ?? fractional.date(from: text)
    }
    static func day(_ text: String, timeZone: TimeZone = .current) -> Date? {
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        guard parts.count == 3, let value = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.year, from: value) == parts[0], calendar.component(.month, from: value) == parts[1], calendar.component(.day, from: value) == parts[2] else { return nil }
        return value
    }
    static func dueValue(_ components: DateComponents?) -> (text: String?, hasTime: Bool) {
        guard var components, let year = components.year, let month = components.month, let day = components.day,
              (1...9999).contains(year) else { return (nil, false) }
        let text = String(format: "%04d-%02d-%02d", year, month, day)
        guard Self.day(text) != nil else { return (nil, false) }
        let hasTime = components.hour != nil || components.minute != nil || components.second != nil
        if !hasTime { return (text, false) }
        guard (0...23).contains(components.hour ?? 0), (0...59).contains(components.minute ?? 0), (0...59).contains(components.second ?? 0) else { return (nil, true) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = components.timeZone ?? .current
        components.calendar = calendar
        guard let value = calendar.date(from: components), calendar.component(.hour, from: value) == (components.hour ?? 0),
              calendar.component(.minute, from: value) == (components.minute ?? 0) else { return (nil, true) }
        return (ISO8601DateFormatter().string(from: value), true)
    }
    func matches(_ query: ScriptWidgetRemindersQuery, selection: ScriptWidgetCalendarSelection) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 2048, title.utf8.count <= 1024, ScriptWidgetCalendarSelection.validIDs([listID]),
              selection.allows(listID), query.window.calendarIDs.isEmpty || ScriptWidgetCalendarSelection.contains(query.window.calendarIDs, listID),
              completed == query.completed, (0...9).contains(priority) else { return false }
        if let due {
            guard hasTime ? Self.isoDate(due) != nil : Self.day(due) != nil else { return false }
        } else if hasTime { return false }
        if completed {
            guard let completedAt, let date = Self.isoDate(completedAt) else { return false }
            return date >= query.window.start && date < query.window.end
        }
        guard completedAt == nil, let due else { return false }
        if hasTime, let date = Self.isoDate(due) { return date >= query.window.start && date < query.window.end }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = query.timeZone
        guard let date = Self.day(due, timeZone: query.timeZone), let end = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        return date < query.window.end && end > query.window.start
    }
}

protocol ScriptWidgetRemindersProviding: AnyObject {
    func authorizationStatus() -> String
    func sources() -> [ScriptWidgetCalendarSource]
    func fetch(_ query: ScriptWidgetRemindersQuery, ids: [String], session: ScriptWidgetExecutionSession,
               completion: @escaping (Result<(items: [ScriptWidgetReminderItem], truncated: Bool), Error>) -> Void)
}

final class ScriptWidgetRemindersSystemProvider: ScriptWidgetRemindersProviding {
    private let store = EKEventStore()
    func authorizationStatus() -> String { ScriptWidgetRuntimeReminders.systemAuthorizationStatus() }
    func sources() -> [ScriptWidgetCalendarSource] {
        store.calendars(for: .reminder).compactMap {
            ScriptWidgetCalendarSelection.validIDs([$0.calendarIdentifier]) ? .init(id: $0.calendarIdentifier, title: String($0.title.prefix(256))) : nil
        }
    }
    func fetch(_ query: ScriptWidgetRemindersQuery, ids: [String], session: ScriptWidgetExecutionSession,
               completion: @escaping (Result<(items: [ScriptWidgetReminderItem], truncated: Bool), Error>) -> Void) {
        let allowed = Set(ids.map { Data($0.utf8) })
        let lists = store.calendars(for: .reminder).filter { allowed.contains(Data($0.calendarIdentifier.utf8)) }
        guard lists.count == ids.count else { completion(.failure(ScriptWidgetRemindersError.invalid("A selected list is unavailable"))); return }
        guard !lists.isEmpty else { completion(.success(([], false))); return }
        let predicate = query.completed
            ? store.predicateForCompletedReminders(withCompletionDateStarting: query.window.start, ending: query.window.end, calendars: lists)
            : store.predicateForIncompleteReminders(withDueDateStarting: query.window.start, ending: query.window.end, calendars: lists)
        let cancellation = ScriptWidgetQueryCancellation(session: session)
        let token = store.fetchReminders(matching: predicate) { [self] reminders in
            cancellation.complete()
            guard session.isActive else { return }
            guard let reminders else { completion(.failure(ScriptWidgetRemindersError.queryFailed)); return }
            var items: [ScriptWidgetReminderItem] = [], scanned = 0
            for reminder in reminders {
                guard session.isActive else { return }
                if scanned >= 1000 { break }
                scanned += 1
                guard reminder.priority <= 9, !reminder.calendarItemIdentifier.isEmpty, reminder.calendarItemIdentifier.utf8.count <= 2048 else { continue }
                let due = ScriptWidgetReminderItem.dueValue(reminder.dueDateComponents)
                let item = ScriptWidgetReminderItem(id: reminder.calendarItemIdentifier, listID: reminder.calendar.calendarIdentifier,
                    title: String((reminder.title ?? "").prefix(256)), due: due.text, hasTime: due.hasTime, completed: reminder.isCompleted,
                    completedAt: reminder.completionDate.map { ISO8601DateFormatter().string(from: $0) }, priority: Int(reminder.priority))
                guard allowed.contains(Data(item.listID.utf8)), item.matches(query, selection: .all) else { continue }
                items.append(item)
            }
            withExtendedLifetime(store) { completion(.success((items, scanned < reminders.count))) }
        }
        guard cancellation.install({ [store] in store.cancelFetchRequest(token) }) else {
            store.cancelFetchRequest(token); return
        }
        if !session.isActive { store.cancelFetchRequest(token); cancellation.complete() }
    }
}

enum ScriptWidgetRemindersCache {
    static let maximumBytes = 64 * 1024
    static func decode(_ data: Data, query: ScriptWidgetRemindersQuery, selection: ScriptWidgetCalendarSelection, now: Date = Date()) -> [String: Any]? {
        guard query.window.maxAgeSeconds > 0, selection.calendarIDs?.isEmpty != true, data.count <= maximumBytes,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["query", "selection", "timestamp", "value"], object["query"] as? String == query.identity,
              object["selection"] as? String == selection.identity,
              let time = object["timestamp"] as? NSNumber, CFGetTypeID(time) != CFBooleanGetTypeID(), time.doubleValue.isFinite,
              time.doubleValue <= now.timeIntervalSince1970, now.timeIntervalSince1970 - time.doubleValue <= query.window.maxAgeSeconds,
              var value = object["value"] as? [String: Any], Set(value.keys) == ["status", "items", "fetchedAt", "source", "stale", "truncated"],
              let items = value["items"] as? [[String: Any]], items.count <= query.window.limit,
              value["status"] as? String == (items.isEmpty ? "empty" : "ready"), value["source"] as? String == "system",
              let fetched = value["fetchedAt"] as? String, ScriptWidgetReminderItem.isoDate(fetched) != nil,
              boolean(value["stale"]) != nil, boolean(value["truncated"]) != nil else { return nil }
        for row in items {
            guard Set(row.keys) == ["id", "listID", "title", "due", "hasTime", "completed", "completedAt", "priority"],
                  let id = row["id"] as? String, let listID = row["listID"] as? String, let title = row["title"] as? String,
                  let hasTime = boolean(row["hasTime"]), let completed = boolean(row["completed"]),
                  let priority = row["priority"] as? NSNumber, CFGetTypeID(priority) != CFBooleanGetTypeID(), priority.doubleValue.isFinite,
                  priority.doubleValue >= 0, priority.doubleValue <= 9, priority.doubleValue.rounded() == priority.doubleValue,
                  row["due"] is NSNull || row["due"] is String, row["completedAt"] is NSNull || row["completedAt"] is String else { return nil }
            let item = ScriptWidgetReminderItem(id: id, listID: listID, title: title, due: row["due"] as? String, hasTime: hasTime,
                completed: completed, completedAt: row["completedAt"] as? String, priority: priority.intValue)
            guard item.matches(query, selection: selection) else { return nil }
        }
        value["source"] = "cache"; value["stale"] = now.timeIntervalSince1970 - time.doubleValue > 60
        return value
    }
    private static func boolean(_ raw: Any?) -> Bool? {
        guard let value = raw as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }; return value.boolValue
    }
}

@objc public class ScriptWidgetRuntimeReminders: NSObject, ScriptWidgetRuntimeRemindersExports {
    private static let queue = DispatchQueue(label: "app.scriptwidget.reminders", qos: .userInitiated)
    static func isAvailable() -> Bool { JSContext.current()?.scriptWidgetRunningState?.previewStorage == nil }
    static func systemAuthorizationStatus() -> String {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, macOS 14.0, *), status == .fullAccess { return "authorized" }
        switch status { case .authorized: return "authorized"; case .denied: return "denied"; case .restricted: return "restricted"; case .notDetermined: return "notDetermined"; default: return "unavailable" }
    }
    private static func permitted(_ state: ScriptWidgetRunningState) -> Bool {
        guard state.previewStorage == nil, let manifest = state.package.readManifest(), manifest.permissions.contains(.reminders) else { return false }
        return WidgetPackageManifestValidator.validate(manifest, package: state.package, checkEntryExists: false).isValid
    }
    private static func defaults(_ state: ScriptWidgetRunningState) -> any ScriptWidgetStorageBackend {
        #if DEBUG
        if let defaults = state.storageDefaultsForTesting { return defaults }
        #endif
        return state.executionSnapshot?.context.defaults ?? (UserDefaults(suiteName: "group.everettjf.scriptwidget") ?? .standard)
    }
    private static func key(_ state: ScriptWidgetRunningState) -> String {
        "ScriptWidget.RemindersCache.v1." + SHA256.hash(data: Data(state.storageNamespace.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    private static func scope(_ state: ScriptWidgetRunningState) throws -> ScriptWidgetCalendarSelection {
        var container = state.executionSnapshot?.context.container ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget")
        #if DEBUG
        container = state.storageContainerForTesting ?? container
        #endif
        return try ScriptWidgetCalendarSelection.load(container: container, kind: .reminders)
    }
    private static func status(_ state: ScriptWidgetRunningState) -> String {
        #if DEBUG
        if let provider = state.remindersProviderForTesting { return provider.authorizationStatus() }
        #endif
        return systemAuthorizationStatus()
    }
    private static func provider(_ state: ScriptWidgetRunningState) -> any ScriptWidgetRemindersProviding {
        #if DEBUG
        if let provider = state.remindersProviderForTesting { return provider }
        #endif
        return ScriptWidgetRemindersSystemProvider()
    }
    static func authorizationStatus() -> String {
        guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution, permitted(state) else { return "undeclared" }
        return status(state)
    }
    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state, state.isCurrentExecution, permitted(state) else { reject.call(withArguments: [ScriptWidgetRemindersError.denied.localizedDescription]); return }
            if state.isTimelineProjection || state.isLiveActivityPresentation { resolve.call(withArguments: [status(state) == "authorized"]); return }
            requestSystemAuthorization { granted, error in
                state.executionSession.callbackQueue.async {
                    guard state.isCurrentExecution else { return }
                    guard permitted(state) else { reject.call(withArguments: [ScriptWidgetRemindersError.denied.localizedDescription]); return }
                    if !granted { try? defaults(state).removeValue(forKey: key(state)) }
                    if let error { reject.call(withArguments: [error]) } else { resolve.call(withArguments: [granted]) }
                }
            }
        }
    }
    static func requestSystemAuthorization(completion: @escaping (Bool, String?) -> Void) {
        #if !IsWidgetTarget
        DispatchQueue.main.async {
            if systemAuthorizationStatus() == "authorized" { completion(true, nil); return }
            let key: String
            if #available(iOS 17.0, macOS 14.0, *) { key = "NSRemindersFullAccessUsageDescription" } else { key = "NSRemindersUsageDescription" }
            guard Bundle.main.object(forInfoDictionaryKey: key) as? String != nil else { completion(false, "Reminders usage description is missing"); return }
            let store = EKEventStore()
            let callback: (Bool, Error?) -> Void = { granted, error in
                store.reset(); DispatchQueue.main.async { completion(granted, error == nil ? nil : "Reminders access could not be requested") }
            }
            if #available(iOS 17.0, macOS 14.0, *) { store.requestFullAccessToReminders(completion: callback) }
            else { store.requestAccess(to: .reminder, completion: callback) }
        }
        #else
        completion(systemAuthorizationStatus() == "authorized", nil)
        #endif
    }
    static func lists() -> ScriptWidgetRuntimePromise { read(nil, error: nil) }
    static func items(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        do { return read(try ScriptWidgetRemindersQuery(options), error: nil) } catch { return read(nil, error: error.localizedDescription) }
    }
    private static func cached(_ query: ScriptWidgetRemindersQuery, _ state: ScriptWidgetRunningState, _ selection: ScriptWidgetCalendarSelection) -> [String: Any]? {
        guard let data = (try? defaults(state).readValue(forKey: key(state))) as? Data else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["selection"] as? String != selection.identity {
            try? defaults(state).removeValue(forKey: key(state)); return nil
        }
        return ScriptWidgetRemindersCache.decode(data, query: query, selection: selection)
    }
    private static func read(_ query: ScriptWidgetRemindersQuery?, error: String?) -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state, state.isCurrentExecution, permitted(state) else { reject.call(withArguments: [ScriptWidgetRemindersError.denied.localizedDescription]); return }
            if let error { reject.call(withArguments: [error]); return }
            guard state.executionSession.registerDataQuery() else { reject.call(withArguments: ["[query_limit] Too many system data queries"]); return }
            guard status(state) == "authorized" else { try? defaults(state).removeValue(forKey: key(state)); reject.call(withArguments: [ScriptWidgetRemindersError.denied.localizedDescription]); return }
            let selection: ScriptWidgetCalendarSelection
            do {
                selection = try scope(state)
                if query != nil, selection.calendarIDs?.isEmpty == true { throw ScriptWidgetRemindersError.noneSelected }
            } catch { try? defaults(state).removeValue(forKey: key(state)); reject.call(withArguments: [(error as? ScriptWidgetRemindersError)?.localizedDescription ?? ScriptWidgetRemindersError.denied.localizedDescription]); return }
            func deliver(_ payload: Any) {
                state.executionSession.callbackQueue.async {
                    guard state.isCurrentExecution else { return }
                    guard permitted(state), status(state) == "authorized", (try? scope(state)) == selection else {
                        try? defaults(state).removeValue(forKey: key(state)); reject.call(withArguments: [ScriptWidgetRemindersError.scopeChanged.localizedDescription]); return
                    }
                    resolve.call(withArguments: [payload])
                }
            }
            if state.isTimelineProjection || state.isLiveActivityPresentation {
                guard let query, let value = cached(query, state, selection) else { reject.call(withArguments: ["[snapshot_required] Open ScriptWidget to refresh this reminder snapshot"]); return }
                deliver(value); return
            }
            queue.async {
                guard state.isCurrentExecution else { return }
                let source = provider(state)
                if query == nil {
                    var seen = Set<Data>()
                    deliver(Array(source.sources().filter { selection.allows($0.id) && ScriptWidgetCalendarSelection.validIDs([$0.id]) && seen.insert($0.identity).inserted }.prefix(64)).map { ["id": $0.id, "title": String($0.title.prefix(256))] }); return
                }
                let query = query!
                if let value = cached(query, state, selection) { deliver(value); return }
                let ids: [String]
                do { ids = try selection.permittedIDs(available: source.sources().map(\.id), requested: query.window.calendarIDs) }
                catch { state.executionSession.callbackQueue.async { if state.isCurrentExecution { reject.call(withArguments: ["[invalid_options] A requested reminder list is unavailable or outside your selection"]) } }; return }
                source.fetch(query, ids: ids, session: state.executionSession) { result in
                    guard state.isCurrentExecution else { return }
                    switch result {
                    case .failure:
                        state.executionSession.callbackQueue.async { if state.isCurrentExecution { reject.call(withArguments: [ScriptWidgetRemindersError.queryFailed.localizedDescription]) } }
                    case .success(let result):
                        let allowed = Set(ids.map { Data($0.utf8) })
                        let items = result.items.filter { allowed.contains(Data($0.listID.utf8)) && $0.matches(query, selection: selection) }
                            .sorted { ($0.completedAt ?? $0.due ?? "", $0.id) < ($1.completedAt ?? $1.due ?? "", $1.id) }
                        let value: [String: Any] = ["status": items.isEmpty ? "empty" : "ready", "items": Array(items.prefix(query.window.limit)).map(\.dictionary),
                            "fetchedAt": ISO8601DateFormatter().string(from: Date()), "source": "system", "stale": false, "truncated": result.truncated || items.count > query.window.limit]
                        if state.isCurrentExecution, permitted(state), status(state) == "authorized", (try? scope(state)) == selection,
                           let data = try? JSONSerialization.data(withJSONObject: ["query": query.identity, "selection": selection.identity, "timestamp": Date().timeIntervalSince1970, "value": value]), data.count <= ScriptWidgetRemindersCache.maximumBytes {
                            try? defaults(state).writeValue(data, forKey: key(state))
                        }
                        deliver(value)
                    }
                }
            }
        }
    }
}

#if !IsWidgetTarget
import SwiftUI
import WidgetKit

@MainActor
struct RemindersAccessSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = ScriptWidgetRuntimeReminders.systemAuthorizationStatus()
    @State private var requesting = false
    @State private var message: String?
    @StateObject private var model = ScriptWidgetCalendarSourcesModel(kind: .reminders)
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(status == "authorized" ? "Reminders Connected" : "Connect Reminders", systemImage: "checklist").font(.headline)
            Text("Apple requires full Reminders access. Widget scripts currently have read-only access to the lists you choose.").font(.footnote).foregroundStyle(.secondary)
            if status == "authorized" { CalendarSourcesSettingsView(model: model) }
            else {
                Button(requesting ? "Requesting Access…" : "Allow Reminders Access") {
                    requesting = true
                    ScriptWidgetRuntimeReminders.requestSystemAuthorization { _, error in
                        requesting = false; status = ScriptWidgetRuntimeReminders.systemAuthorizationStatus(); message = error
                        if status == "authorized" { Task { await model.reload() } }
                    }
                }.disabled(requesting || status == "restricted" || status == "unavailable")
            }
            if status == "denied" || status == "restricted" { Text("Review Reminders access in system privacy settings, then return here.").font(.footnote).foregroundStyle(.secondary) }
            if let message { Text(message).font(.footnote).foregroundStyle(.red) }
        }.task(id: scenePhase) {
            if scenePhase == .active { status = ScriptWidgetRuntimeReminders.systemAuthorizationStatus(); if status == "authorized" { await model.reload() } }
        }
    }
}

struct RemindersAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form { Section("Reminders") { RemindersAccessSettingsView() } }.navigationTitle("Data Access")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 300)
        #endif
    }
}
#endif


/// Validated native mutation input. Rendering environments cannot confer action
/// authority. A request ID is reserved for durable duplicate-execution handling.
struct ScriptWidgetReminderMutation {
    enum Kind: String { case create, update, setCompleted }
    let kind: Kind
    let requestID: String
    let listID: String
    let id: String?
    let title: String?
    let changesDue: Bool
    let due: String?
    let priority: Int?
    let completed: Bool?
    let fingerprint: String

    init(kind: Kind, options: [String: Any]) throws {
        let fields: Set<String>
        switch kind {
        case .create: fields = ["requestID", "listID", "title", "due", "priority"]
        case .update: fields = ["requestID", "listID", "id", "title", "due", "priority"]
        case .setCompleted: fields = ["requestID", "listID", "id", "completed"]
        }
        guard Set(options.keys).isSubset(of: fields),
              let requestID = options["requestID"] as? String,
              UUID(uuidString: requestID)?.uuidString.lowercased() == requestID,
              let listID = options["listID"] as? String, ScriptWidgetCalendarSelection.validIDs([listID]) else {
            throw ScriptWidgetRemindersError.invalid("A mutation requires a canonical request UUID and one listID")
        }
        self.kind = kind; self.requestID = requestID; self.listID = listID
        if kind == .create { id = nil }
        else {
            guard let value = options["id"] as? String, !value.isEmpty, value.utf8.count <= 2048,
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ScriptWidgetRemindersError.invalid("A mutation requires a reminder ID")
            }
            id = value
        }
        if let value = options["title"] {
            guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.utf8.count <= 1024, !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw ScriptWidgetRemindersError.invalid("A title must contain 1–1024 UTF-8 bytes without control characters")
            }
            title = text
        } else {
            guard kind != .create else { throw ScriptWidgetRemindersError.invalid("Creating a reminder requires a title") }
            title = nil
        }
        changesDue = options.keys.contains("due")
        if let value = options["due"], !(value is NSNull) {
            guard let text = value as? String,
                  ScriptWidgetReminderItem.day(text) != nil || ScriptWidgetReminderItem.isoDate(text) != nil else {
                throw ScriptWidgetRemindersError.invalid("due must be a valid calendar day, ISO date-time, or null")
            }
            due = text
        } else { due = nil }
        if let value = options["priority"] {
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue.isFinite, (0...9).contains(number.doubleValue), number.doubleValue.rounded() == number.doubleValue else {
                throw ScriptWidgetRemindersError.invalid("priority must be an integer from 0 to 9")
            }
            priority = number.intValue
        } else { priority = kind == .create ? 0 : nil }
        if kind == .setCompleted {
            guard let number = options["completed"] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
                throw ScriptWidgetRemindersError.invalid("completed must be a Boolean")
            }
            completed = number.boolValue
        } else { completed = nil }
        guard kind != .update || title != nil || changesDue || priority != nil else {
            throw ScriptWidgetRemindersError.invalid("An update requires at least one changed field")
        }
        var identity: [String: Any] = ["kind": kind.rawValue, "listID": listID]
        if let id { identity["id"] = id }
        if let title { identity["title"] = title }
        if changesDue { identity["due"] = due as Any? ?? NSNull() }
        if let priority { identity["priority"] = priority }
        if let completed { identity["completed"] = completed }
        let data = try JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys])
        fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func permitsAction(_ state: ScriptWidgetRunningState) -> Bool {
        state.isUserInitiatedAction && !state.isTimelineProjection && !state.isLiveActivityPresentation
            && state.previewStorage == nil && state.isCurrentExecution
    }
}
