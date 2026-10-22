import Foundation
import JavaScriptCore
#if os(iOS) && !targetEnvironment(macCatalyst)
import MediaPlayer
#endif

@objc protocol ScriptWidgetRuntimeMusicExports: JSExport {
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func current() -> ScriptWidgetRuntimePromise
}

enum ScriptWidgetMusicError: String, LocalizedError {
    case permission, unavailable, cancelled, invalidSnapshot
    var errorDescription: String? {
        switch self {
        case .permission: "[music_permission] Install this widget, declare music and allow Music access in ScriptWidget Settings."
        case .unavailable: "[music_unavailable] Current Music app playback is unavailable on this platform."
        case .cancelled: "[execution_inactive] Music execution is no longer current."
        case .invalidSnapshot: "[music_snapshot] Playback information could not be read."
        }
    }
}

struct ScriptWidgetMusicSnapshot: Equatable {
    let state: String
    let hasItem: Bool
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let position: Double?
    let capturedAt: Date
    static let states = ["playing", "paused", "stopped", "interrupted", "seeking", "unknown"]
    func validate() throws {
        let text: (String?) -> Bool = { $0.map { $0.utf8.count <= 512 && !$0.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) } ?? true }
        guard Self.states.contains(state), [title,artist,album].allSatisfy(text),
              hasItem || (title == nil && artist == nil && album == nil && duration == nil),
              duration.map({ $0.isFinite && $0 > 0 && $0 <= 604800 }) ?? true,
              position.map({ $0.isFinite && $0 >= 0 && $0 <= 604800 }) ?? true,
              capturedAt.timeIntervalSince1970.isFinite else { throw ScriptWidgetMusicError.invalidSnapshot }
    }
    var object: [String:Any] {
        ["provider":"appleMusic", "state":state, "hasItem":hasItem,
         "title":title as Any? ?? NSNull(), "artist":artist as Any? ?? NSNull(), "album":album as Any? ?? NSNull(),
         "duration":duration as Any? ?? NSNull(), "position":position as Any? ?? NSNull(),
         "capturedAt":ISO8601DateFormatter().string(from:capturedAt)]
    }
}

protocol ScriptWidgetMusicProviding {
    func isAvailable() -> Bool
    func authorizationStatus() -> String
    /// System provider must be called on the main thread. No queue or playback
    /// mutations, notification subscriptions, network calls or library scans.
    func read() throws -> ScriptWidgetMusicSnapshot
}

struct ScriptWidgetMusicSystemProvider: ScriptWidgetMusicProviding {
    func isAvailable() -> Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return Bundle.main.object(forInfoDictionaryKey:"NSAppleMusicUsageDescription") is String
        #else
        return false
        #endif
    }
    func authorizationStatus() -> String {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard isAvailable() else { return "unavailable" }
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unavailable"
        }
        #else
        return "unavailable"
        #endif
    }
    func read() throws -> ScriptWidgetMusicSnapshot {
        guard Thread.isMainThread, isAvailable() else { throw ScriptWidgetMusicError.unavailable }
        guard authorizationStatus() == "authorized" else { throw ScriptWidgetMusicError.permission }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let player = MPMusicPlayerController.systemMusicPlayer
        let state: String
        switch player.playbackState {
        case .playing: state = "playing"
        case .paused: state = "paused"
        case .stopped: state = "stopped"
        case .interrupted: state = "interrupted"
        case .seekingForward, .seekingBackward: state = "seeking"
        @unknown default: state = "unknown"
        }
        let item = player.nowPlayingItem
        func text(_ value: String?) -> String? {
            guard let value else { return nil }
            var bounded = String(value.prefix(256))
            while bounded.utf8.count > 512 { bounded.removeLast() }
            return bounded
        }
        let rawDuration = item?.playbackDuration, rawPosition = player.currentPlaybackTime
        let duration = rawDuration.flatMap { $0.isFinite && $0 > 0 && $0 <= 604800 ? $0 : nil }
        let position = rawPosition.isFinite && rawPosition >= 0 && rawPosition <= 604800 ? rawPosition : nil
        let snapshot = ScriptWidgetMusicSnapshot(state:state,hasItem:item != nil,title:text(item?.title),artist:text(item?.artist),album:text(item?.albumTitle),duration:duration,position:position,capturedAt:Date())
        guard authorizationStatus() == "authorized" else { throw ScriptWidgetMusicError.permission }
        try snapshot.validate(); return snapshot
        #else
        throw ScriptWidgetMusicError.unavailable
        #endif
    }
}

/// Per-execution snapshot, never a persisted library/cache. A synchronous widget
/// view may block the main thread while JSC runs on another queue, so the native
/// host prepares this before entering that wait. Async preview callers can read
/// on the main queue without blocking it. All accesses are locked.
final class ScriptWidgetMusicReadCache {
    private let lock = NSLock()
    private var value: Result<ScriptWidgetMusicSnapshot,ScriptWidgetMusicError>?
    func read() -> Result<ScriptWidgetMusicSnapshot,ScriptWidgetMusicError>? { lock.lock(); defer { lock.unlock() }; return value }
    func store(_ result: Result<ScriptWidgetMusicSnapshot,ScriptWidgetMusicError>) { lock.lock(); defer { lock.unlock() }; if value == nil { value = result } }
}

@objc final class ScriptWidgetRuntimeMusic: NSObject, ScriptWidgetRuntimeMusicExports {
    static func permitted(_ state: ScriptWidgetRunningState) -> Bool {
        guard state.isCurrentExecution, state.previewStorage == nil, state.executionSnapshot != nil,
              let manifest = state.package.readManifest(), manifest.permissions.contains(.music) else { return false }
        return WidgetPackageManifestValidator.validate(manifest,package:state.package,checkEntryExists:false).isValid
    }
    private static func provider(_ state: ScriptWidgetRunningState) -> any ScriptWidgetMusicProviding {
        #if DEBUG
        if let value = state.musicProviderForTesting { return value }
        #endif
        return ScriptWidgetMusicSystemProvider()
    }
    static func isAvailable() -> Bool {
        guard let state = JSContext.current()?.scriptWidgetRunningState, permitted(state) else { return false }
        return provider(state).isAvailable()
    }
    static func authorizationStatus() -> String {
        guard let state = JSContext.current()?.scriptWidgetRunningState, permitted(state) else { return "undeclared" }
        return provider(state).authorizationStatus()
    }
    static func prepareForSynchronousHost(_ state: ScriptWidgetRunningState) {
        guard Thread.isMainThread, permitted(state), !state.isTimelineProjection, !state.isLiveActivityPresentation,
              provider(state).isAvailable(), provider(state).authorizationStatus() == "authorized" else { return }
        #if DEBUG
        if ScriptManager.usesIsolatedUnitTestBuildCache && state.musicProviderForTesting == nil { return }
        #endif
        capture(state)
    }
    private static func capture(_ state: ScriptWidgetRunningState) {
        guard state.musicReadCache.read() == nil else { return }
        let result: Result<ScriptWidgetMusicSnapshot,ScriptWidgetMusicError>
        do {
            guard permitted(state), provider(state).authorizationStatus() == "authorized" else { throw ScriptWidgetMusicError.permission }
            let snapshot = try provider(state).read(); try snapshot.validate()
            guard permitted(state), provider(state).authorizationStatus() == "authorized" else { throw ScriptWidgetMusicError.permission }
            result = .success(snapshot)
        } catch { result = .failure(error as? ScriptWidgetMusicError ?? .invalidSnapshot) }
        state.musicReadCache.store(result)
    }
    static func current() -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve,reject in
            guard let state, permitted(state) else { reject.call(withArguments:[ScriptWidgetMusicError.permission.localizedDescription]); return }
            guard !state.isTimelineProjection && !state.isLiveActivityPresentation else { reject.call(withArguments:["[timeline_read_only] Prepare Music display data in the current entry"]); return }
            guard state.executionSession.registerDataQuery() else { reject.call(withArguments:["[query_limit] Too many system data queries"]); return }
            func deliver() {
                state.executionSession.callbackQueue.async {
                    guard state.isCurrentExecution else { return }
                    do {
                        guard permitted(state), provider(state).authorizationStatus() == "authorized" else { throw ScriptWidgetMusicError.permission }
                        guard let result = state.musicReadCache.read() else { throw ScriptWidgetMusicError.unavailable }
                        let snapshot = try result.get(); try snapshot.validate()
                        resolve.call(withArguments:[snapshot.object])
                    } catch { reject.call(withArguments:[(error as? ScriptWidgetMusicError ?? .invalidSnapshot).localizedDescription]) }
                }
            }
            guard provider(state).isAvailable() else { reject.call(withArguments:[ScriptWidgetMusicError.unavailable.localizedDescription]); return }
            guard provider(state).authorizationStatus() == "authorized" else { reject.call(withArguments:[ScriptWidgetMusicError.permission.localizedDescription]); return }
            if state.musicReadCache.read() != nil { deliver(); return }
            let cancellation = ScriptWidgetQueryCancellation(session:state.executionSession)
            let work = DispatchWorkItem {
                cancellation.complete()
                guard state.isCurrentExecution else { return }
                capture(state); deliver()
            }
            guard cancellation.install({ work.cancel() }) else { return }
            DispatchQueue.main.async(execute:work)
        }
    }

    static func requestSystemAuthorization(_ completion: @escaping (Bool) -> Void) {
        #if os(iOS) && !targetEnvironment(macCatalyst) && !IsWidgetTarget
        DispatchQueue.main.async {
            guard ScriptWidgetMusicSystemProvider().isAvailable() else { completion(false); return }
            MPMediaLibrary.requestAuthorization { status in DispatchQueue.main.async { completion(status == .authorized) } }
        }
        #else
        completion(false)
        #endif
    }
}

import SwiftUI
import WidgetKit
struct ScriptWidgetMusicAccessSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = ScriptWidgetMusicSystemProvider().authorizationStatus()
    @State private var requesting = false
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Label("Music App Playback",systemImage:"music.note").font(.headline)
            Text("Allow widgets to show the current Music app track. This reads a playback snapshot only; it does not scan your library, start music or change the queue. Each installed widget must declare Music access.")
                .font(.footnote).foregroundStyle(.secondary)
            if status == "unavailable" {
                Text("Reading the system Music player is unavailable on this platform. Web Studio can preview editable samples.").font(.footnote).foregroundStyle(.secondary)
            } else if status == "authorized" {
                Text("Music access allowed").font(.footnote)
                Button("Refresh Music Widgets") { WidgetCenter.shared.reloadAllTimelines() }
            } else if status == "notDetermined" {
                Button(requesting ? "Requesting Access…" : "Allow Music Access") {
                    requesting = true
                    ScriptWidgetRuntimeMusic.requestSystemAuthorization { _ in
                        requesting = false; status = ScriptWidgetMusicSystemProvider().authorizationStatus()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }.disabled(requesting)
            } else {
                Text("Review Music access in system privacy settings, then reload this screen.").font(.footnote).foregroundStyle(.secondary)
                #if os(iOS)
                Link("Open Settings",destination:URL(string:UIApplication.openSettingsURLString)!)
                #endif
            }
            Text("Only the Music app's shared state is available. Home Sharing or other items may withhold track details. This is not a global now-playing API for every audio app.").font(.footnote).foregroundStyle(.secondary)
        }.task(id:scenePhase) { if scenePhase == .active { status = ScriptWidgetMusicSystemProvider().authorizationStatus() } }
    }
}
