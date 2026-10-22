//
//  ScriptWidgetRuntimeHealth.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import JavaScriptCore

/// HealthKit reveals whether a consent review is needed, not whether each
/// read type was granted. Empty/error-free queries cannot upgrade this state.
enum ScriptWidgetHealthReviewState: Equatable {
    case checking, unavailable, reviewRequired, reviewCompleted, failed

    var readAuthorization: String { "notDisclosed" }

    static func evaluate(available: Bool, shouldRequest: Bool?, failed: Bool = false) -> Self {
        guard available else { return .unavailable }
        guard !failed else { return .failed }
        guard let shouldRequest else { return .reviewRequired }
        return shouldRequest ? .reviewRequired : .reviewCompleted
    }
}

enum ScriptWidgetHealthAccessPolicy {
    static func permits(_ state: ScriptWidgetRunningState) -> Bool {
        guard state.previewStorage == nil, state.isCurrentExecution else { return false }
        guard state.package.hasManifest else { return true }
        guard let manifest = state.package.readManifest(), manifest.permissions.contains(.health) else { return false }
        return WidgetPackageManifestValidator.validate(manifest, package: state.package, checkEntryExists: false).isValid
    }
}

@objc protocol ScriptWidgetRuntimeHealthExports: JSExport {
    // Read-only HealthKit access (no write).
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func requestAuthorization() -> ScriptWidgetRuntimePromise
    static func stepCountToday() -> ScriptWidgetRuntimePromise
    static func activeEnergyToday() -> ScriptWidgetRuntimePromise
    static func heartRateLatest() -> ScriptWidgetRuntimePromise
}

#if canImport(HealthKit)
import HealthKit

@objc public class ScriptWidgetRuntimeHealth: NSObject, ScriptWidgetRuntimeHealthExports {
    private static let healthStore = HKHealthStore()

    static func isAvailable() -> Bool {
        guard JSContext.current()?.scriptWidgetRunningState?.previewStorage == nil else { return false }
        return HKHealthStore.isHealthDataAvailable()
    }

    static var authorizationReadTypes: Set<HKObjectType> {
        var readTypes = Set<HKObjectType>()
        if let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(stepType)
        }
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            readTypes.insert(energyType)
        }
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        }
        return readTypes
    }

    static func authorizationStatus() -> String {
        if let state = JSContext.current()?.scriptWidgetRunningState {
            if state.previewStorage != nil { return "unavailable" }
            if !ScriptWidgetHealthAccessPolicy.permits(state) { return "undeclared" }
        }
        return isAvailable() ? ScriptWidgetHealthReviewState.reviewCompleted.readAuthorization : "unavailable"
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution else {
                reject.call(withArguments: ["[execution_inactive] Health execution is no longer current"])
                return
            }
            guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                reject.call(withArguments: ["[permission_denied] Install this widget and declare health in widget.json"])
                return
            }
            guard !state.isTimelineProjection else {
                reject.call(withArguments: ["[timeline_read_only] Query Health in the current entry, then use a saved display snapshot"])
                return
            }
            guard state.executionSession.registerDataQuery() else {
                reject.call(withArguments: ["[query_limit] System data query limit exceeded"])
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                reject.call(withArguments: ["Health data not available on this device"])
                return
            }

            let readTypes = authorizationReadTypes

            #if IsWidgetTarget
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                    reject.call(withArguments: ["[permission_denied] Health access is unavailable for this execution"])
                    return
                }
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                switch status {
                case .unnecessary:
                    resolve.call(withArguments: [true])
                case .unknown, .shouldRequest:
                    resolve.call(withArguments: [false])
                @unknown default:
                    resolve.call(withArguments: [false])
                }
            }
            #else
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                    reject.call(withArguments: ["[permission_denied] Health access is unavailable for this execution"])
                    return
                }
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                } else {
                    resolve.call(withArguments: [success])
                }
            }
            #endif
        }
    }

    static func stepCountToday() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution else {
                reject.call(withArguments: ["[execution_inactive] Health execution is no longer current"])
                return
            }
            guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                reject.call(withArguments: ["[permission_denied] Install this widget and declare health in widget.json"])
                return
            }
            guard !state.isTimelineProjection else {
                reject.call(withArguments: ["[timeline_read_only] Query Health in the current entry, then use a saved display snapshot"])
                return
            }
            guard state.executionSession.registerDataQuery() else {
                reject.call(withArguments: ["[query_limit] System data query limit exceeded"])
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                reject.call(withArguments: ["[unavailable] Health data not available on this device"])
                return
            }
            guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                reject.call(withArguments: ["Step count type unavailable"])
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let cancellation = ScriptWidgetQueryCancellation(session: state.executionSession)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                cancellation.complete()
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                    reject.call(withArguments: ["[permission_denied] Health access is unavailable for this execution"])
                    return
                }
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                let quantity = result?.sumQuantity()
                let value = quantity?.doubleValue(for: HKUnit.count()) ?? 0
                resolve.call(withArguments: [[
                    "value": value,
                    "hasSamples": quantity != nil,
                    "unit": "count",
                    "start": isoString(start),
                    "end": isoString(Date())
                ]])
            }
            guard state.isCurrentExecution, cancellation.install({ healthStore.stop(query) }) else { return }
            healthStore.execute(query)
            if !state.isCurrentExecution { healthStore.stop(query); cancellation.complete() }
        }
    }

    static func activeEnergyToday() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution else {
                reject.call(withArguments: ["[execution_inactive] Health execution is no longer current"])
                return
            }
            guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                reject.call(withArguments: ["[permission_denied] Install this widget and declare health in widget.json"])
                return
            }
            guard !state.isTimelineProjection else {
                reject.call(withArguments: ["[timeline_read_only] Query Health in the current entry, then use a saved display snapshot"])
                return
            }
            guard state.executionSession.registerDataQuery() else {
                reject.call(withArguments: ["[query_limit] System data query limit exceeded"])
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                reject.call(withArguments: ["[unavailable] Health data not available on this device"])
                return
            }
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                reject.call(withArguments: ["Active energy type unavailable"])
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let cancellation = ScriptWidgetQueryCancellation(session: state.executionSession)
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                cancellation.complete()
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                    reject.call(withArguments: ["[permission_denied] Health access is unavailable for this execution"])
                    return
                }
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                let quantity = result?.sumQuantity()
                let value = quantity?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                resolve.call(withArguments: [[
                    "value": value,
                    "hasSamples": quantity != nil,
                    "unit": "kcal",
                    "start": isoString(start),
                    "end": isoString(Date())
                ]])
            }
            guard state.isCurrentExecution, cancellation.install({ healthStore.stop(query) }) else { return }
            healthStore.execute(query)
            if !state.isCurrentExecution { healthStore.stop(query); cancellation.complete() }
        }
    }

    static func heartRateLatest() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution else {
                reject.call(withArguments: ["[execution_inactive] Health execution is no longer current"])
                return
            }
            guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                reject.call(withArguments: ["[permission_denied] Install this widget and declare health in widget.json"])
                return
            }
            guard !state.isTimelineProjection else {
                reject.call(withArguments: ["[timeline_read_only] Query Health in the current entry, then use a saved display snapshot"])
                return
            }
            guard state.executionSession.registerDataQuery() else {
                reject.call(withArguments: ["[query_limit] System data query limit exceeded"])
                return
            }
            guard HKHealthStore.isHealthDataAvailable() else {
                reject.call(withArguments: ["[unavailable] Health data not available on this device"])
                return
            }
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                reject.call(withArguments: ["Heart rate type unavailable"])
                return
            }

            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let cancellation = ScriptWidgetQueryCancellation(session: state.executionSession)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                cancellation.complete()
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetHealthAccessPolicy.permits(state) else {
                    reject.call(withArguments: ["[permission_denied] Health access is unavailable for this execution"])
                    return
                }
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    resolve.call(withArguments: [[
                        "value": 0,
                        "hasSamples": false,
                        "unit": "bpm",
                        "start": "",
                        "end": ""
                    ]])
                    return
                }
                let unit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = sample.quantity.doubleValue(for: unit)
                resolve.call(withArguments: [[
                    "value": value,
                    "hasSamples": true,
                    "unit": "bpm",
                    "start": isoString(sample.startDate),
                    "end": isoString(sample.endDate)
                ]])
            }
            guard state.isCurrentExecution, cancellation.install({ healthStore.stop(query) }) else { return }
            healthStore.execute(query)
            if !state.isCurrentExecution { healthStore.stop(query); cancellation.complete() }
        }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
#else
@objc public class ScriptWidgetRuntimeHealth: NSObject, ScriptWidgetRuntimeHealthExports {
    static func isAvailable() -> Bool {
        return false
    }

    static func authorizationStatus() -> String {
        if let state = JSContext.current()?.scriptWidgetRunningState {
            if state.previewStorage != nil { return "unavailable" }
            if !ScriptWidgetHealthAccessPolicy.permits(state) { return "undeclared" }
        }
        return isAvailable() ? ScriptWidgetHealthReviewState.reviewCompleted.readAuthorization : "unavailable"
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return rejectedPromise("HealthKit not available on this platform")
    }

    static func stepCountToday() -> ScriptWidgetRuntimePromise {
        return rejectedPromise("HealthKit not available on this platform")
    }

    static func activeEnergyToday() -> ScriptWidgetRuntimePromise {
        return rejectedPromise("HealthKit not available on this platform")
    }

    static func heartRateLatest() -> ScriptWidgetRuntimePromise {
        return rejectedPromise("HealthKit not available on this platform")
    }

    private static func rejectedPromise(_ message: String) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { _, reject in
            if let state = JSContext.current()?.scriptWidgetRunningState, !ScriptWidgetHealthAccessPolicy.permits(state) {
                reject.call(withArguments: ["[permission_denied] Install this widget and declare health in widget.json"])
            } else { reject.call(withArguments: [message]) }
        }
    }
}
#endif
