//
//  ScriptWidgetRuntimeLocation.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeLocationExports: JSExport {
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func requestAuthorization(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
    static func current(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
}

#if canImport(CoreLocation) && !IsWidgetTarget && os(iOS)
import CoreLocation

@objc public class ScriptWidgetRuntimeLocation: NSObject, ScriptWidgetRuntimeLocationExports {
    private static var activeRequests = [LocationRequest]()

    static func isAvailable() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }

    static func authorizationStatus() -> String {
        guard CLLocationManager.locationServicesEnabled() else {
            return "disabled"
        }
        let manager = CLLocationManager()
        return statusString(for: manager.authorizationStatus)
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return requestAuthorization(nil)
    }

    static func requestAuthorization(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard CLLocationManager.locationServicesEnabled() else {
                reject.call(withArguments: ["Location services are disabled on this device"])
                return
            }

            let status = CLLocationManager().authorizationStatus
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                resolve.call(withArguments: [true])
                return
            case .denied, .restricted:
                resolve.call(withArguments: [false])
                return
            case .notDetermined:
                break
            @unknown default:
                resolve.call(withArguments: [false])
                return
            }

            let timeoutSeconds = timeoutSeconds(from: options, defaultSeconds: 10)
            let request = LocationRequest(
                mode: .authorization,
                timeoutSeconds: timeoutSeconds,
                accuracyMode: .reduced,
                purposeKey: nil,
                maxAgeSeconds: 0,
                resolve: resolve,
                reject: reject
            )
            activeRequests.append(request)
            request.start()
        }
    }

    static func current() -> ScriptWidgetRuntimePromise {
        return current(nil)
    }

    static func current(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard CLLocationManager.locationServicesEnabled() else {
                reject.call(withArguments: ["Location services are disabled on this device"])
                return
            }

            let status = CLLocationManager().authorizationStatus
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                break
            case .notDetermined:
                reject.call(withArguments: ["Location permission not determined. Authorize in the main app settings."])
                return
            case .restricted, .denied:
                reject.call(withArguments: ["Location permission denied. Enable Location access in Settings."])
                return
            @unknown default:
                reject.call(withArguments: ["Unknown location authorization status"])
                return
            }

            let timeoutSeconds = timeoutSeconds(from: options, defaultSeconds: 10)
            let maxAgeSeconds = maxAgeSeconds(from: options, defaultSeconds: 0)
            let settings = accuracySettings(from: options)
            let request = LocationRequest(
                mode: .location,
                timeoutSeconds: timeoutSeconds,
                accuracyMode: settings.mode,
                purposeKey: settings.purposeKey,
                maxAgeSeconds: maxAgeSeconds,
                resolve: resolve,
                reject: reject
            )
            activeRequests.append(request)
            request.start()
        }
    }

    private static func statusString(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func accuracyAuthorizationString(_ manager: CLLocationManager) -> String {
        if #available(iOS 14.0, *) {
            switch manager.accuracyAuthorization {
            case .fullAccuracy:
                return "full"
            case .reducedAccuracy:
                return "reduced"
            @unknown default:
                return "unknown"
            }
        }
        return "unknown"
    }

    private static func timeoutSeconds(from options: [String: Any]?, defaultSeconds: Double) -> Double {
        guard let options = options else { return defaultSeconds }
        if let timeoutMs = options["timeoutMs"] as? Double, timeoutMs > 0 {
            return timeoutMs / 1000
        }
        if let timeoutSeconds = options["timeout"] as? Double, timeoutSeconds > 0 {
            return timeoutSeconds
        }
        return defaultSeconds
    }

    private static func maxAgeSeconds(from options: [String: Any]?, defaultSeconds: Double) -> Double {
        guard let options = options else { return defaultSeconds }
        if let maxAgeMs = options["maxAgeMs"] as? Double, maxAgeMs > 0 {
            return maxAgeMs / 1000
        }
        if let maxAgeSeconds = options["maxAge"] as? Double, maxAgeSeconds > 0 {
            return maxAgeSeconds
        }
        return defaultSeconds
    }

    private enum AccuracyMode {
        case reduced
        case full
    }

    private static func accuracySettings(from options: [String: Any]?) -> (mode: AccuracyMode, purposeKey: String?) {
        guard let options = options else { return (.reduced, nil) }
        let modeString = (options["accuracy"] as? String)?.lowercased() ?? "reduced"
        let mode: AccuracyMode = modeString == "full" ? .full : .reduced
        let purposeKey = options["purposeKey"] as? String
        return (mode, purposeKey)
    }

    private enum RequestMode {
        case authorization
        case location
    }

    private final class LocationRequest: NSObject, CLLocationManagerDelegate {
        private let mode: RequestMode
        private let timeoutSeconds: Double
        private let accuracyMode: AccuracyMode
        private let purposeKey: String?
        private let maxAgeSeconds: Double
        private let resolve: JSValue
        private let reject: JSValue
        private let manager: CLLocationManager
        private var finished = false
        private var timeoutWorkItem: DispatchWorkItem?

        init(mode: RequestMode, timeoutSeconds: Double, accuracyMode: AccuracyMode = .reduced, purposeKey: String?, maxAgeSeconds: Double = 0, resolve: JSValue, reject: JSValue) {
            self.mode = mode
            self.timeoutSeconds = timeoutSeconds
            self.accuracyMode = accuracyMode
            self.purposeKey = purposeKey
            self.maxAgeSeconds = maxAgeSeconds
            self.resolve = resolve
            self.reject = reject
            self.manager = CLLocationManager()
            super.init()
            self.manager.delegate = self
            switch accuracyMode {
            case .full:
                self.manager.desiredAccuracy = kCLLocationAccuracyBest
            case .reduced:
                self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
            }
        }

        func start() {
            DispatchQueue.main.async {
                if self.mode == .location, self.tryResolveCachedLocation() {
                    return
                }
                self.scheduleTimeout()
                switch self.mode {
                case .authorization:
                    self.manager.requestWhenInUseAuthorization()
                case .location:
                    self.requestLocation()
                }
            }
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            handleAuthorizationChange(manager.authorizationStatus)
        }

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            handleAuthorizationChange(status)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard !finished else { return }
            finished = true
            cancelTimeout()
            manager.stopUpdatingLocation()

            guard let location = locations.last else {
                reject.call(withArguments: ["Unable to read current location"])
                ScriptWidgetRuntimeLocation.finish(request: self)
                return
            }

            resolve.call(withArguments: [payload(for: location, isStale: false)])
            ScriptWidgetRuntimeLocation.finish(request: self)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            guard !finished else { return }
            finished = true
            cancelTimeout()
            manager.stopUpdatingLocation()
            reject.call(withArguments: [error.localizedDescription])
            ScriptWidgetRuntimeLocation.finish(request: self)
        }

        private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
            guard mode == .authorization else { return }
            guard !finished else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                finished = true
                cancelTimeout()
                resolve.call(withArguments: [true])
                ScriptWidgetRuntimeLocation.finish(request: self)
            case .denied, .restricted:
                finished = true
                cancelTimeout()
                resolve.call(withArguments: [false])
                ScriptWidgetRuntimeLocation.finish(request: self)
            case .notDetermined:
                break
            @unknown default:
                finished = true
                cancelTimeout()
                resolve.call(withArguments: [false])
                ScriptWidgetRuntimeLocation.finish(request: self)
            }
        }

        private func scheduleTimeout() {
            guard timeoutSeconds > 0 else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard !self.finished else { return }
                self.finished = true
                self.manager.stopUpdatingLocation()
                switch self.mode {
                case .authorization:
                    self.resolve.call(withArguments: [false])
                case .location:
                    if let cached = self.manager.location {
                        self.resolve.call(withArguments: [self.payload(for: cached, isStale: true)])
                    } else {
                        self.reject.call(withArguments: ["Location request timed out"])
                    }
                }
                ScriptWidgetRuntimeLocation.finish(request: self)
            }
            timeoutWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: workItem)
        }

        private func cancelTimeout() {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }

        private func requestLocation() {
            if accuracyMode == .full {
                requestFullAccuracyIfNeeded { [weak self] in
                    self?.beginLocationUpdates()
                }
            } else {
                beginLocationUpdates()
            }
        }

        private func requestFullAccuracyIfNeeded(completion: @escaping () -> Void) {
            if #available(iOS 14.0, *) {
                if manager.accuracyAuthorization == .reducedAccuracy,
                   let purposeKey = purposeKey,
                   !purposeKey.isEmpty {
                    manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey) { _ in
                        completion()
                    }
                    return
                }
            }
            completion()
        }

        private func beginLocationUpdates() {
            manager.requestLocation()
            manager.startUpdatingLocation()
        }

        private func tryResolveCachedLocation() -> Bool {
            guard maxAgeSeconds > 0 else { return false }
            if #available(iOS 14.0, *), accuracyMode == .full, manager.accuracyAuthorization == .reducedAccuracy {
                return false
            }
            guard let location = manager.location else { return false }
            let ageSeconds = max(0, Date().timeIntervalSince(location.timestamp))
            guard ageSeconds <= maxAgeSeconds else { return false }
            finished = true
            resolve.call(withArguments: [payload(for: location, isStale: false)])
            ScriptWidgetRuntimeLocation.finish(request: self)
            return true
        }

        private func payload(for location: CLLocation, isStale: Bool = false) -> [String: Any] {
            let ageSeconds = max(0, Date().timeIntervalSince(location.timestamp))
            return [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "altitude": location.altitude,
                "accuracy": location.horizontalAccuracy,
                "verticalAccuracy": location.verticalAccuracy,
                "speed": location.speed,
                "course": location.course,
                "timestamp": ScriptWidgetRuntimeLocation.isoString(location.timestamp),
                "accuracyAuthorization": ScriptWidgetRuntimeLocation.accuracyAuthorizationString(manager),
                "age": ageSeconds,
                "isStale": isStale
            ]
        }
    }

    private static func finish(request: LocationRequest) {
        if let index = activeRequests.firstIndex(where: { $0 === request }) {
            activeRequests.remove(at: index)
        }
    }
}
#else
@objc public class ScriptWidgetRuntimeLocation: NSObject, ScriptWidgetRuntimeLocationExports {
    static func isAvailable() -> Bool {
        return false
    }

    static func authorizationStatus() -> String {
        return "unavailable"
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return requestAuthorization(nil)
    }

    static func requestAuthorization(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return rejectedPromise("Location services are not available on this platform")
    }

    static func current() -> ScriptWidgetRuntimePromise {
        return current(nil)
    }

    static func current(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return rejectedPromise("Location services are not available on this platform")
    }

    private static func rejectedPromise(_ message: String) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { _, reject in
            reject.call(withArguments: [message])
        }
    }
}
#endif
