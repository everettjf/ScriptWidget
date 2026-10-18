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


/// Interrupts synchronous JavaScript (e.g. `while (true) {}`) that cancelling
/// network tasks cannot stop. Arms JavaScriptCore's watchdog on a context's
/// group: after `slice` seconds of uninterrupted execution JSC asks
/// `shouldTerminate`; `true` throws an uncatchable termination exception that
/// unwinds the script and releases the VM. JSC does not re-arm the limit
/// after the callback declines, so the callback re-installs it each slice.
///
/// `JSContextGroupSetExecutionTimeLimit` is exported by JavaScriptCore on
/// every supported iOS/macOS release but declared only in its private
/// header, so it is resolved at runtime; if it is ever absent the watchdog
/// is not installed and execution behaves as before.
final class ScriptWidgetJavaScriptWatchdog {
    private typealias ShouldTerminateCallback = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Bool
    private typealias SetExecutionTimeLimit = @convention(c) (OpaquePointer?, Double, ShouldTerminateCallback?, UnsafeMutableRawPointer?) -> Void

    private static let setExecutionTimeLimit: SetExecutionTimeLimit? = {
        // RTLD_DEFAULT is a macro Swift does not import.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "JSContextGroupSetExecutionTimeLimit") else {
            return nil
        }
        return unsafeBitCast(symbol, to: SetExecutionTimeLimit.self)
    }()

    static var isSupported: Bool { setExecutionTimeLimit != nil }

    private let slice: TimeInterval
    private let shouldTerminate: () -> Bool
    private let lock = NSLock()
    private var terminated = false

    /// True once the watchdog has asked JSC to terminate a script.
    var didTerminate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminated
    }

    private init(slice: TimeInterval, shouldTerminate: @escaping () -> Bool) {
        self.slice = slice
        self.shouldTerminate = shouldTerminate
    }

    private static let callback: ShouldTerminateCallback = { context, info in
        guard let info else { return true }
        let watchdog = Unmanaged<ScriptWidgetJavaScriptWatchdog>.fromOpaque(info).takeUnretainedValue()
        if watchdog.evaluate() { return true }
        // Start the next slice for the still-running script.
        if let context, let group = JSContextGetGroup(context) {
            watchdog.arm(group)
        }
        return false
    }

    private func arm(_ group: JSContextGroupRef) {
        Self.setExecutionTimeLimit?(group, slice, Self.callback, Unmanaged.passUnretained(self).toOpaque())
    }

    /// Installs a watchdog on `context`'s group. The watchdog is retained by
    /// the context, so the callback's unretained pointer outlives any script
    /// that can run on it.
    @discardableResult
    static func install(on context: JSContext, slice: TimeInterval, shouldTerminate: @escaping () -> Bool) -> ScriptWidgetJavaScriptWatchdog? {
        guard isSupported, let group = JSContextGetGroup(context.jsGlobalContextRef) else { return nil }
        let watchdog = ScriptWidgetJavaScriptWatchdog(slice: slice, shouldTerminate: shouldTerminate)
        context.scriptWidgetWatchdog = watchdog
        watchdog.arm(group)
        return watchdog
    }

    // Called by JSC on the executing thread while it holds the VM lock.
    private func evaluate() -> Bool {
        guard shouldTerminate() else { return false }
        lock.lock()
        terminated = true
        lock.unlock()
        return true
    }
}

private var scriptWidgetWatchdogAssociationKey: UInt8 = 0

private extension JSContext {
    var scriptWidgetWatchdog: ScriptWidgetJavaScriptWatchdog? {
        get { objc_getAssociatedObject(self, &scriptWidgetWatchdogAssociationKey) as? ScriptWidgetJavaScriptWatchdog }
        set { objc_setAssociatedObject(self, &scriptWidgetWatchdogAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
