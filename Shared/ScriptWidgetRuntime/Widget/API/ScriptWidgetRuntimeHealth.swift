//
//  ScriptWidgetRuntimeHealth.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeHealthExports: JSExport {
    // Read-only HealthKit access (no write).
    static func isAvailable() -> Bool
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
        return HKHealthStore.isHealthDataAvailable()
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard HKHealthStore.isHealthDataAvailable() else {
                reject.call(withArguments: ["Health data not available on this device"]) 
                return
            }

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

            #if IsWidgetTarget
            healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, error in
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
            guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                reject.call(withArguments: ["Step count type unavailable"]) 
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                let quantity = result?.sumQuantity()
                let value = quantity?.doubleValue(for: HKUnit.count()) ?? 0
                resolve.call(withArguments: [[
                    "value": value,
                    "unit": "count",
                    "start": isoString(start),
                    "end": isoString(Date())
                ]])
            }
            healthStore.execute(query)
        }
    }

    static func activeEnergyToday() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                reject.call(withArguments: ["Active energy type unavailable"]) 
                return
            }

            let start = Calendar.current.startOfDay(for: Date())
            let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                let quantity = result?.sumQuantity()
                let value = quantity?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                resolve.call(withArguments: [[
                    "value": value,
                    "unit": "kcal",
                    "start": isoString(start),
                    "end": isoString(Date())
                ]])
            }
            healthStore.execute(query)
        }
    }

    static func heartRateLatest() -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                reject.call(withArguments: ["Heart rate type unavailable"]) 
                return
            }

            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    resolve.call(withArguments: [[
                        "value": 0,
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
                    "unit": "bpm",
                    "start": isoString(sample.startDate),
                    "end": isoString(sample.endDate)
                ]])
            }
            healthStore.execute(query)
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
            reject.call(withArguments: [message])
        }
    }
}
#endif
