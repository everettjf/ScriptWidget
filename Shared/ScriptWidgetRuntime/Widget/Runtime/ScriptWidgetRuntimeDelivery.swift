import Foundation
import Combine

enum ScriptWidgetError: Error {
    case undefinedRender(String)

    case internalError(String)
    case transformError(String)
    case scriptError(String)
    case scriptException(String)
    case resourceLimit(String)

    /// The underlying message, used both for logging and for surfacing the
    /// failure to the user in the widget/preview instead of a blank view.
    var displayMessage: String {
        switch self {
        case .undefinedRender(let msg),
             .internalError(let msg),
             .transformError(let msg),
             .scriptError(let msg),
             .scriptException(let msg),
             .resourceLimit(let msg):
            return msg
        }
    }

    var category: String {
        switch self {
        case .undefinedRender: return "Render"
        case .internalError: return "Internal"
        case .transformError: return "Syntax"
        case .scriptError, .scriptException: return "Runtime"
        case .resourceLimit: return "Resource Limit"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .undefinedRender: return "Call $render(...) once from the main script."
        case .internalError: return "Retry. If this persists, export the package and report the diagnostic."
        case .transformError: return "Check the highlighted JSX syntax and property values."
        case .scriptError, .scriptException: return "Use the reported line and stack trace to inspect the script."
        case .resourceLimit: return "Reduce source size, imported work, network data, or execution time."
        }
    }

    var diagnosticMessage: String { "[\(category)] \(displayMessage)\n\(recoverySuggestion)" }
}


/// Subscription, Future fulfillment and cancellation share one serial lane.
/// The result lock alone cannot protect Combine's internal callback lifetime.
final class ScriptWidgetPublisherLane: @unchecked Sendable {
    let queue = DispatchQueue(label: "ScriptWidget.RuntimePublisher", qos: .userInitiated)

    func fulfill<Value>(_ promise: @escaping Future<Value, ScriptWidgetError>.Promise) -> Future<Value, ScriptWidgetError>.Promise {
        let queue = queue
        return { result in queue.async { promise(result) } }
    }
}

/// A single terminal result crosses the worker/caller boundary. In particular,
/// timeout may race with synchronous subscription completion/installation.
// All mutable state is locked; the completed value is handed to one waiter.
final class ScriptWidgetSynchronousResult<Value>: @unchecked Sendable {
    let publisherLane: ScriptWidgetPublisherLane
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var value: Value?
    private var result: Result<Value, ScriptWidgetError>?
    private var subscription: AnyCancellable?

    init(publisherLane: ScriptWidgetPublisherLane = ScriptWidgetPublisherLane()) {
        self.publisherLane = publisherLane
    }

    private func cancel(_ subscription: AnyCancellable?) {
        guard let subscription else { return }
        // Never tear down a Combine subscription on the waiting thread while
        // its receive/completion callback may still be executing.
        publisherLane.queue.async { subscription.cancel() }
    }

    func receive(_ value: Value) {
        lock.lock(); defer { lock.unlock() }
        if result == nil { self.value = value }
    }

    func finish(_ completion: Subscribers.Completion<ScriptWidgetError>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        switch completion {
        case .failure(let error): result = .failure(error)
        case .finished:
            if let value { result = .success(value) }
            else { result = .failure(.internalError("Execution completed without producing a result")) }
        }
        lock.unlock()
        semaphore.signal()
    }

    func install(_ subscription: AnyCancellable) {
        lock.lock()
        if result != nil { lock.unlock(); cancel(subscription) }
        else { self.subscription = subscription; lock.unlock() }
    }

    func wait(until deadline: DispatchTime, onTimeout: () -> Void = {}) -> (Value?, ScriptWidgetError?) {
        _ = semaphore.wait(timeout: deadline)
        lock.lock()
        let timedOut = result == nil
        if timedOut { result = .failure(.resourceLimit("Script exceeded the 5-second execution limit")) }
        let terminal = result!
        let token = subscription
        subscription = nil
        value = nil
        lock.unlock()
        if timedOut { onTimeout() }
        cancel(token)
        switch terminal {
        case .success(let value): return (value, nil)
        case .failure(let error): return (nil, error)
        }
    }
}

