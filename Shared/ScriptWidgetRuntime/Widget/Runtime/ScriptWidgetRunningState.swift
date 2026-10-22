//
//  ScriptWidgetRunningState.swift
//  ScriptWidget
//
//  Created by everettjf on 2022/4/7.
//
//  Per-execution state — package handle and console logger — that the
//  JS runtime APIs (`$file`, `$console`) need to reach. The state hangs
//  off the owning `JSContext` via an associated object; JSExport
//  callbacks find it by way of `JSContext.current()`. There is no
//  global; concurrent runtimes do not see each other's state.
//

import Foundation
import JavaScriptCore

enum ScriptWidgetExecutionCancellation: String, Equatable {
    case timeout
    case superseded
    case explicit
    case completed
}

final class ScriptWidgetExecutionSession {
    static let maximumConcurrentNetworkRequests = 8
    static let maximumTotalNetworkRequests = 32

    static let maximumDataQueries = 8

    let id = UUID()
    let callbackQueue = DispatchQueue(label: "ScriptWidget.ExecutionCallbacks", qos: .userInitiated)
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: URLSessionTask] = [:]
    private var cancellationHandlers: [UUID: () -> Void] = [:]
    private(set) var totalDataQueries = 0
    private(set) var totalNetworkRequests = 0
    private(set) var cancellation: ScriptWidgetExecutionCancellation?

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellation == nil
    }

    func registerDataQuery() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard cancellation == nil, totalDataQueries < Self.maximumDataQueries else { return false }
        totalDataQueries += 1
        return true
    }

    func register(_ task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard cancellation == nil,
              tasks.count < Self.maximumConcurrentNetworkRequests,
              totalNetworkRequests < Self.maximumTotalNetworkRequests else { return false }
        tasks[ObjectIdentifier(task)] = task
        totalNetworkRequests += 1
        return true
    }

    func complete(_ task: URLSessionTask) {
        lock.lock()
        tasks.removeValue(forKey: ObjectIdentifier(task))
        lock.unlock()
    }

    /// Native read queries share the execution's cancellation lifetime.
    func registerCancellation(_ handler: @escaping () -> Void) -> UUID? {
        lock.lock(); defer { lock.unlock() }
        guard cancellation == nil, cancellationHandlers.count < Self.maximumDataQueries else { return nil }
        let id = UUID()
        cancellationHandlers[id] = handler
        return id
    }

    func completeCancellation(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        cancellationHandlers.removeValue(forKey: id)
    }

    func cancel(_ reason: ScriptWidgetExecutionCancellation) {
        lock.lock()
        guard cancellation == nil else {
            lock.unlock()
            return
        }
        cancellation = reason
        let activeTasks = Array(tasks.values)
        let handlers = Array(cancellationHandlers.values)
        tasks.removeAll()
        cancellationHandlers.removeAll()
        lock.unlock()
        activeTasks.forEach { $0.cancel() }
        handlers.forEach { $0() }
    }

    func finish() {
        cancel(.completed)
    }
}

/// Handles a query completing while its cancellation registration is installed.
final class ScriptWidgetQueryCancellation {
    private let session: ScriptWidgetExecutionSession
    private let lock = NSLock()
    private var registration: UUID?
    private var finished = false
    private var installed = false

    init(session: ScriptWidgetExecutionSession) { self.session = session }

    func install(_ cancel: @escaping () -> Void) -> Bool {
        lock.lock()
        guard !finished, !installed else { lock.unlock(); return false }
        installed = true
        lock.unlock()
        guard let id = session.registerCancellation(cancel) else { return false }
        lock.lock()
        if finished { lock.unlock(); session.completeCancellation(id); return false }
        registration = id
        lock.unlock()
        return true
    }

    func complete() {
        lock.lock()
        finished = true
        let id = registration
        registration = nil
        lock.unlock()
        if let id { session.completeCancellation(id) }
    }
}


/// Public JavaScriptCore APIs only. Compiled scripts call the immutable guard
/// at loop iterations, function entry and exception handlers. Cancellation is
/// sticky, so a script cannot catch a timeout and resume another guarded loop.
/// Dynamic code is disabled: it would bypass the compiler's instrumentation.
enum ScriptWidgetExecutionGuard {
    static let identifier = "__scriptWidgetCheckExecution"

    static func install(on context: JSContext, session: ScriptWidgetExecutionSession) {
        let active: @convention(block) () -> Bool = { session.isActive }
        context["__scriptWidgetExecutionActive"] = unsafeBitCast(active, to: JSValue.self)
        context.evaluateScript("""
            (function(active) {
                const timeout = Object.freeze(new Error('Script execution cancelled or timed out'));
                const check = function() { if (!active()) throw timeout; };
                Object.defineProperty(globalThis, '__scriptWidgetCheckExecution', {
                    value: check, writable: false, configurable: false
                });
                delete globalThis.__scriptWidgetExecutionActive;
                const unsupported = function() {
                    throw new Error('Dynamic code (eval and Function constructors) is unsupported; use $import for package source');
                };
                // Preserve Function.prototype.bind/apply/call for ordinary
                // functions and compatibility libraries; only code generation
                // through the constructor is disabled.
                unsupported.prototype = Function.prototype;
                const constructors = [Function, (function*(){}).constructor,
                    (async function(){}).constructor, (async function*(){}).constructor];
                for (const constructor of constructors) {
                    Object.defineProperty(constructor.prototype, 'constructor', {
                        value: unsupported, writable: false, configurable: false
                    });
                }
                for (const name of ['eval', 'Function']) {
                    Object.defineProperty(globalThis, name, {
                        value: unsupported, writable: false, configurable: false
                    });
                }
            })(__scriptWidgetExecutionActive);
            """)
    }
}


class ScriptWidgetConsoleLogger {
    static let maximumEntries = 500
    static let maximumEntryBytes = 8 * 1_024
    var logs: [String] = []

    func addLog(_ log: String) {
        let bounded = String(decoding: log.utf8.prefix(Self.maximumEntryBytes), as: UTF8.self)
        DispatchQueue.main.async {
            self.logs.append(bounded)
            if self.logs.count > Self.maximumEntries {
                self.logs.removeFirst(self.logs.count - Self.maximumEntries)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}


class ScriptWidgetRunningState {

    var logger: ScriptWidgetConsoleLogger
    private(set) var package: ScriptWidgetPackage
    let executionSession: ScriptWidgetExecutionSession

    #if DEBUG
    var storageContainerForTesting: URL?
    var storageDefaultsForTesting: UserDefaults?
    var fetchManagerForTesting: ScriptWidgetFetchManager?
    var calendarProviderForTesting: ScriptWidgetCalendarProvider?
    var photosProviderForTesting: (any ScriptWidgetPhotosProviding)?
    var remindersProviderForTesting: (any ScriptWidgetRemindersProviding)?
    #endif

    /// Native action dispatch authority; never derived from script environments.
    let isUserInitiatedAction: Bool
    let isDarkMode: Bool?
    let isTimelineProjection: Bool
    let isLiveActivityPresentation: Bool
    private(set) var executionSnapshot: ScriptWidgetExecutionSnapshot?
    let previewStorage: ScriptWidgetPreviewStorageBackend?

    var storageNamespace: String { executionSnapshot?.storageNamespace ?? "script.\(package.name)." }

    var fetchManager: ScriptWidgetFetchManager {
        #if DEBUG
        if let fetchManagerForTesting { return fetchManagerForTesting }
        #endif
        return sharedFetchManager
    }

    init(package: ScriptWidgetPackage, isDarkMode: Bool? = nil, isTimelineProjection: Bool = false, isLiveActivityPresentation: Bool = false, executionSnapshot: ScriptWidgetExecutionSnapshot? = nil, isUserInitiatedAction: Bool = false) {
        self.isUserInitiatedAction = isUserInitiatedAction
        self.isDarkMode = isDarkMode
        self.isTimelineProjection = isTimelineProjection
        self.isLiveActivityPresentation = isLiveActivityPresentation
        self.executionSnapshot = executionSnapshot
        self.previewStorage = package.readonly && executionSnapshot == nil ? ScriptWidgetPreviewStorageBackend(namespace: "script.\(package.name).") : nil
        self.logger = ScriptWidgetConsoleLogger()
        self.package = package
        self.executionSession = ScriptWidgetExecutionSession()
        #if DEBUG
        if executionSnapshot == nil, package.managedScope == nil, ScriptManager.usesIsolatedUnitTestBuildCache {
            storageContainerForTesting = ScriptManager.localFallbackDirectoryURL("__Build").deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: storageContainerForTesting!, withIntermediateDirectories: true)
        }
        #endif
    }

    /// Capture managed editor/renderer input before JavaScript starts while
    /// retaining the same cancellation session installed in the JS guard.
    func captureManagedEntry(_ source: String) throws {
        guard executionSnapshot == nil, let scope = package.managedScope else { return }
        try scope.validate(name: package.name)
        guard previewStorage == nil, executionSession.isActive,
              package.path.standardizedFileURL.resolvingSymlinksInPath() == scope.context.libraryRoot.appendingPathComponent(package.name) else {
            throw ScriptWidgetStorageNamespaceError.conflict
        }
        let snapshot = try ScriptWidgetExecutionSnapshot(name: package.name, role: scope.role, context: scope.context, entryOverride: source)
        package = snapshot.package
        executionSnapshot = snapshot
    }

    func validateExecutionSnapshot() throws {
        do {
            if let executionSnapshot { try executionSnapshot.validateIdentity() }
            else if previewStorage == nil {
                #if DEBUG
                let root = storageContainerForTesting ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget")
                #else
                let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget")
                #endif
                try ScriptWidgetStorageProfiles.validateLegacyExecution(container: root)
            }
        } catch { executionSession.cancel(.superseded); throw error }
    }

    var isCurrentExecution: Bool {
        guard executionSession.isActive else { return false }
        do { try validateExecutionSnapshot(); return executionSession.isActive }
        catch { return false }
    }
}

private var scriptWidgetRunningStateAssociationKey: UInt8 = 0

extension JSContext {
    /// Per-runtime running state. Read inside JSExport callbacks via
    /// `JSContext.current()?.scriptWidgetRunningState`.
    var scriptWidgetRunningState: ScriptWidgetRunningState? {
        get {
            objc_getAssociatedObject(self, &scriptWidgetRunningStateAssociationKey) as? ScriptWidgetRunningState
        }
        set {
            objc_setAssociatedObject(
                self,
                &scriptWidgetRunningStateAssociationKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
