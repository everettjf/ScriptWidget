//
//  ScriptWidgetRuntimeLocation.swift
//  ScriptWidget
//
//  Created by ScriptWidget contributors.
//

import Foundation
import CoreFoundation
import JavaScriptCore

@objc protocol ScriptWidgetRuntimeLocationExports: JSExport {
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func isAuthorizedForWidgetUpdates() -> Bool
    static func requestAuthorization(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
    static func current(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
}

/// Deterministic permission and cache policy, shared by app/extension paths.
enum ScriptWidgetLocationPolicy {
    static func packageAllows(_ package: ScriptWidgetPackage) -> Bool {
        guard package.hasManifest else { return true } // Preserve genuine legacy packages.
        guard let manifest = package.readManifest(), manifest.permissions.contains(.location) else { return false }
        return WidgetPackageManifestValidator.validate(manifest, package: package, checkEntryExists: false).isValid
    }

    static func canRead(servicesEnabled: Bool, status: String, widget: Bool, widgetAuthorized: Bool) -> Bool {
        servicesEnabled && ["authorizedAlways", "authorizedWhenInUse"].contains(status) && (!widget || widgetAuthorized)
    }
}

enum ScriptWidgetLocationCache {
    static let key = "ScriptWidget.LocationCache.v1"
    static let maximumBytes = 4 * 1_024
    static let maximumAge: TimeInterval = 86_400

    static func read(defaults: UserDefaults, allowed: Bool, accuracyAuthorization: String, maxAgeSeconds: Double?, now: Date = Date()) -> [String: Any]? {
        _ = defaults.synchronize()
        guard allowed, let data = defaults.data(forKey: key),
              let payload = decode(data, accuracyAuthorization: accuracyAuthorization, maxAgeSeconds: maxAgeSeconds, now: now) else {
            defaults.removeObject(forKey: key)
            _ = defaults.synchronize()
            return nil
        }
        return payload
    }

    static func decode(_ data: Data, accuracyAuthorization: String, maxAgeSeconds: Double?, now: Date = Date()) -> [String: Any]? {
        guard data.count <= maximumBytes,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(raw.keys) == ["latitude", "longitude", "altitude", "accuracy", "verticalAccuracy", "speed", "course", "timestampSeconds", "accuracyAuthorization"],
              let precision = raw["accuracyAuthorization"] as? String, ["full", "reduced"].contains(precision),
              ["full", "reduced"].contains(accuracyAuthorization),
              accuracyAuthorization != "reduced" || precision == "reduced" else { return nil }
        var numbers: [String: Double] = [:]
        for key in ["latitude", "longitude", "altitude", "accuracy", "verticalAccuracy", "speed", "course", "timestampSeconds"] {
            guard let number = raw[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return nil }
            numbers[key] = number.doubleValue
        }
        guard (-90...90).contains(numbers["latitude"]!), (-180...180).contains(numbers["longitude"]!),
              numbers["accuracy"]! >= 0 else { return nil }
        let timestamp = Date(timeIntervalSince1970: numbers["timestampSeconds"]!)
        let age = now.timeIntervalSince(timestamp)
        guard age >= 0, age <= maximumAge else { return nil }
        var payload = raw
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        payload["timestamp"] = formatter.string(from: timestamp)
        payload["age"] = age
        payload["isStale"] = age > max(0, min(maximumAge, maxAgeSeconds ?? 0))
        payload.removeValue(forKey: "timestampSeconds")
        return payload
    }
}

#if canImport(CoreLocation) && os(iOS)
import CoreLocation

@objc public class ScriptWidgetRuntimeLocation: NSObject, ScriptWidgetRuntimeLocationExports {
    private static var activeRequests = [LocationRequest]()
    private static let locationCacheKey = ScriptWidgetLocationCache.key

    private static func defaults() -> UserDefaults {
        return UserDefaults(suiteName: "group.everettjf.scriptwidget") ?? UserDefaults.standard
    }

    static func isAvailable() -> Bool {
        guard JSContext.current()?.scriptWidgetRunningState?.previewStorage == nil else { return false }
        let enabled = CLLocationManager.locationServicesEnabled()
        if !enabled { clearCache() }
        return enabled
    }

    static func authorizationStatus() -> String {
        if JSContext.current()?.scriptWidgetRunningState?.previewStorage != nil { return "unavailable" }
        guard let state = JSContext.current()?.scriptWidgetRunningState,
              state.isCurrentExecution,
              ScriptWidgetLocationPolicy.packageAllows(state.package) else { return "undeclared" }
        refreshAuthorizationState()
        guard CLLocationManager.locationServicesEnabled() else { return "disabled" }
        return statusString(for: CLLocationManager().authorizationStatus)
    }

    static func isAuthorizedForWidgetUpdates() -> Bool {
        guard let state = JSContext.current()?.scriptWidgetRunningState,
              state.isCurrentExecution,
              state.previewStorage == nil,
              ScriptWidgetLocationPolicy.packageAllows(state.package) else { return false }
        let manager = CLLocationManager()
        return ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: true, widgetAuthorized: manager.isAuthorizedForWidgetUpdates)
    }

    private static var isWidget: Bool {
        #if IsWidgetTarget
        return true
        #else
        return false
        #endif
    }

    private static func permittedState(_ reject: JSValue) -> ScriptWidgetRunningState? {
        guard let state = JSContext.current()?.scriptWidgetRunningState, state.isCurrentExecution else { return nil }
        guard !state.isLiveActivityPresentation else {
            reject.call(withArguments:["[live_activity_unavailable] Live Activity presentations cannot request location updates; update their state from the app"])
            return nil
        }
        guard state.previewStorage == nil else {
            reject.call(withArguments: ["[permission_denied] Install this widget to use location data"])
            return nil
        }
        guard ScriptWidgetLocationPolicy.packageAllows(state.package) else {
            reject.call(withArguments: ["[permission_denied] Declare location in widget.json"])
            return nil
        }
        guard state.executionSession.registerDataQuery() else {
            reject.call(withArguments: ["[query_limit] System data query limit exceeded"])
            return nil
        }
        return state
    }

    static func clearCache() {
        defaults().removeObject(forKey: locationCacheKey)
        _ = defaults().synchronize()
    }

    /// Also called by the app's permission UI when returning from Settings.
    static func refreshAuthorizationState() {
        let manager = CLLocationManager()
        let allowed = ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: isWidget, widgetAuthorized: manager.isAuthorizedForWidgetUpdates)
        _ = ScriptWidgetLocationCache.read(defaults: defaults(), allowed: allowed, accuracyAuthorization: accuracyAuthorizationString(manager), maxAgeSeconds: nil)
    }

    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        return requestAuthorization(nil)
    }

    static func requestAuthorization(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = permittedState(reject) else { return }
            refreshAuthorizationState()
            if state.isTimelineProjection {
                let manager = CLLocationManager()
                resolve.call(withArguments: [ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: isWidget, widgetAuthorized: manager.isAuthorizedForWidgetUpdates)])
                return
            }
            #if IsWidgetTarget
            resolve.call(withArguments: [isAuthorizedForWidgetUpdates()])
            #else
            guard CLLocationManager.locationServicesEnabled() else {
                reject.call(withArguments: ["[unavailable] Location services are disabled on this device"])
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
            DispatchQueue.main.async {
                guard state.isCurrentExecution else { return }
                let request = LocationRequest(
                    state: state,
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
            #endif
        }
    }

    static func current() -> ScriptWidgetRuntimePromise {
        return current(nil)
    }

    static func current(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state = permittedState(reject) else { return }
            refreshAuthorizationState()
            if state.isTimelineProjection {
                if let cached = cachedLocationPayload(maxAgeSeconds: maxAgeSeconds(from: options, defaultSeconds: 0)) {
                    resolve.call(withArguments: [cached])
                } else { reject.call(withArguments: ["[timeline_read_only] No authorized Location snapshot is available"]) }
                return
            }
            #if IsWidgetTarget
            guard isAuthorizedForWidgetUpdates() else {
                reject.call(withArguments: ["[widget_not_authorized] Allow location for widgets in Settings"])
                return
            }
            let cachedMaxAgeSeconds = maxAgeSeconds(from: options, defaultSeconds: 0)
            if let cached = cachedLocationPayload(maxAgeSeconds: cachedMaxAgeSeconds) {
                resolve.call(withArguments: [cached])
            } else {
                reject.call(withArguments: ["[no_data] Location data unavailable. Open the main app to refresh location."])
            }
            #else
            guard CLLocationManager.locationServicesEnabled() else {
                reject.call(withArguments: ["[unavailable] Location services are disabled on this device"])
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
            DispatchQueue.main.async {
                guard state.isCurrentExecution else { return }
                let request = LocationRequest(
                    state: state,
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
            #endif
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

    static func accuracyAuthorizationString(_ manager: CLLocationManager) -> String {
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
        if let timeoutMs = options["timeoutMs"] as? Double, timeoutMs.isFinite, timeoutMs > 0 {
            return min(30, timeoutMs / 1000)
        }
        if let timeoutSeconds = options["timeout"] as? Double, timeoutSeconds.isFinite, timeoutSeconds > 0 {
            return min(30, timeoutSeconds)
        }
        return defaultSeconds
    }

    private static func maxAgeSeconds(from options: [String: Any]?, defaultSeconds: Double) -> Double {
        guard let options = options else { return defaultSeconds }
        if let maxAgeMs = options["maxAgeMs"] as? Double, maxAgeMs.isFinite, maxAgeMs > 0 {
            return min(ScriptWidgetLocationCache.maximumAge, maxAgeMs / 1000)
        }
        if let maxAgeSeconds = options["maxAge"] as? Double, maxAgeSeconds.isFinite, maxAgeSeconds > 0 {
            return min(ScriptWidgetLocationCache.maximumAge, maxAgeSeconds)
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
        let rawKey = options["purposeKey"] as? String
        let declared = Bundle.main.object(forInfoDictionaryKey: "NSLocationTemporaryUsageDescriptionDictionary") as? [String: Any] ?? [:]
        let purposeKey = rawKey.flatMap { $0.utf8.count <= 128 && declared[$0] is String ? $0 : nil }
        return (mode, purposeKey)
    }

    private enum RequestMode {
        case authorization
        case location
    }

    private final class LocationRequest: NSObject, CLLocationManagerDelegate {
        private let state: ScriptWidgetRunningState
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
        private var cancellationTimer: DispatchSourceTimer?

        init(state: ScriptWidgetRunningState, mode: RequestMode, timeoutSeconds: Double, accuracyMode: AccuracyMode = .reduced, purposeKey: String?, maxAgeSeconds: Double = 0, resolve: JSValue, reject: JSValue) {
            self.state = state
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
            guard self.validateExecution() else { return }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self, !self.state.isCurrentExecution else { return }
                _ = self.validateExecution()
            }
            self.cancellationTimer = timer
            timer.resume()
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

        @discardableResult
        private func validateExecution() -> Bool {
            guard !finished else { return false }
            guard state.isCurrentExecution else {
                finished = true
                cancelTimeout()
                manager.stopUpdatingLocation()
                ScriptWidgetRuntimeLocation.finish(request: self)
                return false
            }
            guard ScriptWidgetLocationPolicy.packageAllows(state.package) else {
                fail("[permission_denied] Declare location in widget.json")
                return false
            }
            return true
        }

        private func authorizedToRead() -> Bool {
            // Delegate authorization is safe to inspect on the main run loop.
            // Recheck service availability off-main immediately before JS delivery.
            [CLAuthorizationStatus.authorizedAlways, .authorizedWhenInUse].contains(manager.authorizationStatus)
        }

        private func deliverFailure(_ message: String) {
            let state = state
            let reject = reject
            DispatchQueue.global(qos: .userInitiated).async {
                guard state.isCurrentExecution else { return }
                reject.call(withArguments: [message])
            }
        }

        private func deliverSuccess(_ value: Any) {
            let state = state
            let resolve = resolve
            let reject = reject
            DispatchQueue.global(qos: .userInitiated).async {
                guard state.isCurrentExecution else { return }
                guard ScriptWidgetLocationPolicy.packageAllows(state.package) else {
                    reject.call(withArguments: ["[permission_denied] Declare location in widget.json"])
                    return
                }
                if let payload = value as? [String: Any] {
                    let manager = CLLocationManager()
                    guard ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: ScriptWidgetRuntimeLocation.statusString(for: manager.authorizationStatus), widget: false, widgetAuthorized: false),
                          ScriptWidgetRuntimeLocation.accuracyAuthorizationString(manager) != "reduced" || payload["accuracyAuthorization"] as? String == "reduced" else {
                        ScriptWidgetRuntimeLocation.clearCache()
                        reject.call(withArguments: ["[permission_denied] Location access or precision changed"])
                        return
                    }
                }
                resolve.call(withArguments: [value])
            }
        }

        private func fail(_ message: String) {
            guard !finished else { return }
            finished = true
            cancelTimeout()
            manager.stopUpdatingLocation()
            if state.isCurrentExecution { deliverFailure(message) }
            ScriptWidgetRuntimeLocation.finish(request: self)
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            handleAuthorizationChange(manager.authorizationStatus)
        }

        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            handleAuthorizationChange(status)
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard validateExecution() else { return }
            guard authorizedToRead() else {
                ScriptWidgetRuntimeLocation.clearCache()
                fail("[permission_denied] Location access changed")
                return
            }
            guard let location = locations.last, location.horizontalAccuracy >= 0,
                  CLLocationCoordinate2DIsValid(location.coordinate),
                  Date().timeIntervalSince(location.timestamp) >= 0,
                  Date().timeIntervalSince(location.timestamp) <= ScriptWidgetLocationCache.maximumAge else {
                fail("[no_data] No valid location fix is available")
                return
            }
            finished = true
            cancelTimeout()
            manager.stopUpdatingLocation()

            let payload = payload(for: location, isStale: false)
            ScriptWidgetRuntimeLocation.cacheLocation(
                location,
                accuracyAuthorization: ScriptWidgetRuntimeLocation.accuracyAuthorizationString(manager)
            )
            if authorizedToRead(), state.isCurrentExecution,
               ScriptWidgetLocationPolicy.packageAllows(state.package) {
                deliverSuccess(payload)
            } else {
                ScriptWidgetRuntimeLocation.clearCache()
                if state.isCurrentExecution { deliverFailure("[permission_denied] Location access changed") }
            }
            ScriptWidgetRuntimeLocation.finish(request: self)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            guard validateExecution() else { return }
            if !authorizedToRead() { ScriptWidgetRuntimeLocation.clearCache() }
            fail("[location_error] Unable to obtain a location fix")
        }

        private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
            guard validateExecution() else { return }
            if !authorizedToRead() {
                ScriptWidgetRuntimeLocation.clearCache()
                if mode == .location {
                    fail("[permission_denied] Location access changed")
                    return
                }
            }
            guard mode == .authorization else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                finished = true
                cancelTimeout()
                deliverSuccess(true)
                ScriptWidgetRuntimeLocation.finish(request: self)
            case .denied, .restricted:
                finished = true
                cancelTimeout()
                deliverSuccess(false)
                ScriptWidgetRuntimeLocation.finish(request: self)
            case .notDetermined:
                break
            @unknown default:
                finished = true
                cancelTimeout()
                deliverSuccess(false)
                ScriptWidgetRuntimeLocation.finish(request: self)
            }
        }

        private func scheduleTimeout() {
            guard timeoutSeconds > 0 else { return }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard self.validateExecution() else { return }
                guard self.mode == .authorization || self.authorizedToRead() else {
                    ScriptWidgetRuntimeLocation.clearCache()
                    self.fail("[permission_denied] Location access changed")
                    return
                }
                self.finished = true
                self.cancelTimeout()
                self.manager.stopUpdatingLocation()
                switch self.mode {
                case .authorization:
                    self.deliverSuccess(false)
                case .location:
                    if self.manager.accuracyAuthorization == .fullAccuracy,
                       let cached = self.manager.location, cached.horizontalAccuracy >= 0,
                       CLLocationCoordinate2DIsValid(cached.coordinate),
                       Date().timeIntervalSince(cached.timestamp) >= 0,
                       Date().timeIntervalSince(cached.timestamp) <= ScriptWidgetLocationCache.maximumAge {
                        self.deliverSuccess(self.payload(for: cached, isStale: true))
                    } else {
                        self.deliverFailure("Location request timed out")
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
            cancellationTimer?.cancel()
            cancellationTimer = nil
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
            guard validateExecution(), authorizedToRead() else { return }
            manager.requestLocation()
            manager.startUpdatingLocation()
        }

        private func tryResolveCachedLocation() -> Bool {
            guard validateExecution(), authorizedToRead(), maxAgeSeconds > 0,
                  manager.accuracyAuthorization == .fullAccuracy else { return false }
            if #available(iOS 14.0, *), accuracyMode == .full, manager.accuracyAuthorization == .reducedAccuracy {
                return false
            }
            guard let location = manager.location else { return false }
            let ageSeconds = Date().timeIntervalSince(location.timestamp)
            guard CLLocationCoordinate2DIsValid(location.coordinate), location.horizontalAccuracy >= 0,
                  ageSeconds >= 0, ageSeconds <= ScriptWidgetLocationCache.maximumAge, ageSeconds <= maxAgeSeconds else { return false }
            finished = true
            cancelTimeout()
            deliverSuccess(payload(for: location, isStale: false))
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

    static func cacheLocation(_ location: CLLocation, accuracyAuthorization: String) {
        if Thread.isMainThread {
            DispatchQueue.global(qos: .utility).async {
                cacheLocation(location, accuracyAuthorization: accuracyAuthorization)
            }
            return
        }
        let manager = CLLocationManager()
        guard ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: isWidget, widgetAuthorized: manager.isAuthorizedForWidgetUpdates) else {
            clearCache()
            return
        }
        let payload: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "accuracy": location.horizontalAccuracy,
            "verticalAccuracy": location.verticalAccuracy,
            "speed": location.speed,
            "course": location.course,
            "timestampSeconds": location.timestamp.timeIntervalSince1970,
            "accuracyAuthorization": accuracyAuthorization
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            guard ScriptWidgetLocationCache.decode(data, accuracyAuthorization: accuracyAuthorizationString(manager), maxAgeSeconds: nil) != nil else { return }
            defaults().set(data, forKey: locationCacheKey)
            _ = defaults().synchronize()
        } catch { /* Cache failure must not log location values. */ }
    }

    private static func cachedLocationPayload(maxAgeSeconds: Double?) -> [String: Any]? {
        let manager = CLLocationManager()
        let allowed = ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: isWidget, widgetAuthorized: manager.isAuthorizedForWidgetUpdates)
        let payload = ScriptWidgetLocationCache.read(defaults: defaults(), allowed: allowed, accuracyAuthorization: accuracyAuthorizationString(manager), maxAgeSeconds: maxAgeSeconds)
        // Recheck immediately before returning cached private data.
        guard ScriptWidgetLocationPolicy.canRead(servicesEnabled: CLLocationManager.locationServicesEnabled(), status: statusString(for: manager.authorizationStatus), widget: isWidget, widgetAuthorized: manager.isAuthorizedForWidgetUpdates) else {
            clearCache()
            return nil
        }
        return payload
    }

}
#else
@objc public class ScriptWidgetRuntimeLocation: NSObject, ScriptWidgetRuntimeLocationExports {
    static func isAuthorizedForWidgetUpdates() -> Bool { false }

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
            if JSContext.current()?.scriptWidgetRunningState?.isLiveActivityPresentation == true {
                reject.call(withArguments:["[live_activity_unavailable] Live Activity presentations cannot request location updates; update their state from the app"])
            } else if JSContext.current()?.scriptWidgetRunningState?.previewStorage != nil {
                reject.call(withArguments: ["[permission_denied] Install this widget to use location data"])
            } else { reject.call(withArguments: [message]) }
        }
    }
}
#endif
