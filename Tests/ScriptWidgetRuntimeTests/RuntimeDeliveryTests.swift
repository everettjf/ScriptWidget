import Foundation
import Combine
import XCTest
#if !SCRIPTWIDGET_DELIVERY_STANDALONE_TESTS
@testable import ScriptWidget
#endif

final class RuntimeDeliveryReferenceTests: XCTestCase {
    private final class Payload: NSObject { let number: Int; init(_ number: Int) { self.number = number } }
    private final class WeakPayload { weak var value: Payload?; init(_ value: Payload?) { self.value = value } }

    @objc func testReferencePayloadsSurviveEarlyCompletionAndConcurrentWaiterCancellation() throws {
        let requested = Int(ProcessInfo.processInfo.environment["SCRIPTWIDGET_DELIVERY_STRESS_ITERATIONS"] ?? "20000") ?? 20000
        let iterations = min(1_000_000, max(1, requested))
        let lane = ScriptWidgetPublisherLane()
        var failures = 0, retained: [WeakPayload] = []
        for index in 0..<iterations {
            autoreleasepool {
                let result = ScriptWidgetSynchronousResult<Payload>(publisherLane: lane)
                lane.queue.async {
                    let token = Future<Int, ScriptWidgetError> { $0(.success(index)) }
                        .flatMap { value in
                            Future<Payload, ScriptWidgetError> { rawPromise in
                                let promise = lane.fulfill(rawPromise)
                                // Mimic a native SDK completing on another queue.
                                DispatchQueue.global().async { promise(.success(Payload(value))) }
                            }
                        }
                        .sink(receiveCompletion: { result.finish($0) }, receiveValue: { result.receive($0) })
                    result.install(token)
                }
                let output = result.wait(until: .now() + .seconds(2))
                if output.1 != nil || output.0?.number != index { failures += 1 }
                if index >= iterations - 16 { retained.append(WeakPayload(output.0)) }
            }
        }
        // Let completed producer stacks and queued cancellations unwind.
        lane.queue.sync {}
        XCTAssertEqual(failures, 0, "Reference results must not disappear or be exchanged between executions")
        XCTAssertTrue(retained.allSatisfy { $0.value == nil }, "Finished subscriptions must release native result objects")
    }

    @objc func testCancellationRunsOnPublisherLaneAfterCompletionReturns() {
        let lane = ScriptWidgetPublisherLane(), key = DispatchSpecificKey<Bool>()
        lane.queue.setSpecific(key: key, value: true)
        let result = ScriptWidgetSynchronousResult<String>(publisherLane: lane)
        var completionReturned = false, cancelledOnLane = false, cancelledAfterCompletion = false
        lane.queue.async {
            result.install(AnyCancellable {
                cancelledOnLane = DispatchQueue.getSpecific(key: key) == true
                cancelledAfterCompletion = completionReturned
            })
            result.receive("ready"); result.finish(.finished)
            // The waiting thread may already have woken. Cancellation must not
            // destroy a callback while its native completion frame is active.
            Thread.sleep(forTimeInterval: 0.002)
            completionReturned = true
        }
        let output = result.wait(until: .now() + .seconds(2))
        XCTAssertEqual(output.0, "ready"); XCTAssertNil(output.1)
        lane.queue.sync {}
        XCTAssertTrue(cancelledOnLane); XCTAssertTrue(cancelledAfterCompletion)
    }

    @objc func testTimeoutRejectsLateValuesAndCancelsLateSubscriptionOnLane() {
        let lane = ScriptWidgetPublisherLane(), result = ScriptWidgetSynchronousResult<Int>(publisherLane: lane)
        var timedOut = false, cancelled = false
        let output = result.wait(until: .now()) { timedOut = true }
        XCTAssertNil(output.0); XCTAssertEqual(output.1?.category, "Resource Limit"); XCTAssertTrue(timedOut)
        lane.queue.async {
            result.receive(7); result.finish(.finished)
            result.install(AnyCancellable { cancelled = true })
        }
        // Installation itself schedules cancellation after the active frame.
        lane.queue.sync {}; lane.queue.sync {}
        XCTAssertTrue(cancelled)
    }

    @objc func testNativeFailureAndEmptyCompletionRemainExplicitErrors() {
        for completion: Subscribers.Completion<ScriptWidgetError> in [.failure(.scriptError("sample failure")), .finished] {
            let result = ScriptWidgetSynchronousResult<NSObject>()
            result.publisherLane.queue.async { result.finish(completion) }
            let output = result.wait(until: .now() + .seconds(2))
            XCTAssertNil(output.0); XCTAssertNotNil(output.1)
            XCTAssertEqual(output.1?.category, completion.isFinished ? "Internal" : "Runtime")
        }
    }
}

private extension Subscribers.Completion where Failure == ScriptWidgetError {
    var isFinished: Bool { if case .finished = self { return true }; return false }
}
