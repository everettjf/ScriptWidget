//
//  ScriptWidgetRuntimePromise.swift
//  ScriptWidget
//
//  Created by everettjf on 2020/12/10.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimePromiseExports: JSExport {
    func then(_ resolve: JSValue, _ reject: JSValue) -> Void
}

class ScriptWidgetRuntimePromise: NSObject, ScriptWidgetRuntimePromiseExports {
    
    var callback: (JSValue,JSValue) -> Void
    private let state: ScriptWidgetRunningState?
    
    init(callback: @escaping (JSValue,JSValue) -> Void) {
        self.callback = callback
        self.state = JSContext.current()?.scriptWidgetRunningState
    }
    
    func then(_ resolve: JSValue, _ reject: JSValue) -> Void {
        guard let state = state ?? resolve.context?.scriptWidgetRunningState else { self.callback(resolve, reject); return }
        guard state.isCurrentExecution else {
            reject.call(withArguments: ["[execution_inactive] The widget execution is no longer current"])
            return
        }
        let delivery = ScriptWidgetPromiseDelivery(state: state, resolve: resolve, reject: reject)
        let success: @convention(block) (JSValue) -> Void = { delivery.finish($0, rejected: false) }
        let failure: @convention(block) (JSValue) -> Void = { delivery.finish($0, rejected: true) }
        guard let guardedResolve = JSValue(object: success, in: resolve.context),
              let guardedReject = JSValue(object: failure, in: reject.context) else {
            reject.call(withArguments: ["[execution_unavailable] Promise delivery could not be installed"])
            return
        }
        self.callback(guardedResolve, guardedReject)
    }
}

/// At most one callback can cross back into JS. Native payloads from a finished
/// or replaced execution are discarded before invoking user continuations.
final class ScriptWidgetPromiseDelivery: NSObject {
    private let state: ScriptWidgetRunningState
    private let resolve: JSManagedValue
    private let reject: JSManagedValue
    private weak var virtualMachine: JSVirtualMachine?
    private let lock = NSLock()
    private var settled = false

    init(state: ScriptWidgetRunningState, resolve: JSValue, reject: JSValue) {
        self.state = state
        self.resolve = JSManagedValue(value: resolve)
        self.reject = JSManagedValue(value: reject)
        self.virtualMachine = resolve.context?.virtualMachine
        super.init()
        // The VM owns the native callback blocks, which own this delivery.
        // Strong JSValues here would root that same VM through a native cycle.
        virtualMachine?.addManagedReference(self.resolve, withOwner: self)
        virtualMachine?.addManagedReference(self.reject, withOwner: self)
    }

    deinit {
        virtualMachine?.removeManagedReference(resolve, withOwner: self)
        virtualMachine?.removeManagedReference(reject, withOwner: self)
    }

    func finish(_ value: JSValue, rejected: Bool) {
        state.executionSession.callbackQueue.async { self.deliver(value, rejected: rejected) }
    }

    private func deliver(_ value: JSValue, rejected: Bool) {
        lock.lock()
        guard !settled else { lock.unlock(); return }
        settled = true
        lock.unlock()
        let success = resolve.value
        let failure = reject.value
        virtualMachine?.removeManagedReference(resolve, withOwner: self)
        virtualMachine?.removeManagedReference(reject, withOwner: self)
        guard state.executionSession.isActive else { return }
        guard state.isCurrentExecution else {
            failure?.call(withArguments: ["[execution_identity_changed] Reload the widget before continuing"])
            return
        }
        (rejected ? failure : success)?.call(withArguments: [value])
    }
}
