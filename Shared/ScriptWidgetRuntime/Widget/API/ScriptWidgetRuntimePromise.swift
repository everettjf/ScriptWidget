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
final class ScriptWidgetPromiseDelivery {
    private let state: ScriptWidgetRunningState
    private let resolve: JSValue
    private let reject: JSValue
    private let lock = NSLock()
    private var settled = false

    init(state: ScriptWidgetRunningState, resolve: JSValue, reject: JSValue) {
        self.state = state; self.resolve = resolve; self.reject = reject
    }

    func finish(_ value: JSValue, rejected: Bool) {
        state.executionSession.callbackQueue.async { self.deliver(value, rejected: rejected) }
    }

    private func deliver(_ value: JSValue, rejected: Bool) {
        lock.lock()
        guard !settled else { lock.unlock(); return }
        settled = true
        lock.unlock()
        guard state.executionSession.isActive else { return }
        guard state.isCurrentExecution else {
            reject.call(withArguments: ["[execution_identity_changed] Reload the widget before continuing"])
            return
        }
        (rejected ? reject : resolve).call(withArguments: [value])
    }
}
