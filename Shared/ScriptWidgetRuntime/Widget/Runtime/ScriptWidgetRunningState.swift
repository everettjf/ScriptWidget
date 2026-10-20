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

    let id = UUID()
    private let lock = NSLock()
    private var tasks: [ObjectIdentifier: URLSessionTask] = [:]
    private(set) var totalNetworkRequests = 0
    private(set) var cancellation: ScriptWidgetExecutionCancellation?

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancellation == nil
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

    func cancel(_ reason: ScriptWidgetExecutionCancellation) {
        lock.lock()
        guard cancellation == nil else {
            lock.unlock()
            return
        }
        cancellation = reason
        let activeTasks = Array(tasks.values)
        tasks.removeAll()
        lock.unlock()
        activeTasks.forEach { $0.cancel() }
    }

    func finish() {
        cancel(.completed)
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
    var package: ScriptWidgetPackage
    let executionSession: ScriptWidgetExecutionSession

    let isDarkMode: Bool?

    var storageNamespace: String { "script.\(package.name)." }

    init(package: ScriptWidgetPackage, isDarkMode: Bool? = nil) {
        self.isDarkMode = isDarkMode
        self.logger = ScriptWidgetConsoleLogger()
        self.package = package
        self.executionSession = ScriptWidgetExecutionSession()
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
