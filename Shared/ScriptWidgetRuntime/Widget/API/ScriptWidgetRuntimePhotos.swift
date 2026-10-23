import Foundation
import CoreFoundation
import Darwin
import JavaScriptCore
import Photos
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

@objc protocol ScriptWidgetRuntimePhotosExports: JSExport {
    static func isAvailable() -> Bool
    static func authorizationStatus() -> String
    static func requestAuthorization() -> ScriptWidgetRuntimePromise
    static func items(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise
}

enum ScriptWidgetPhotosError: LocalizedError {
    case invalid, denied, unavailable, changed, cacheMiss
    var errorDescription: String? {
        switch self {
        case .invalid: "[invalid_options] Invalid photo options or selection"
        case .denied: "[permission_denied] Allow Photos access and choose photos or albums in ScriptWidget Settings"
        case .unavailable: "[unavailable] Photos could not be loaded"
        case .changed: "[scope_changed] Photo access changed. Reload and try again."
        case .cacheMiss: "[cache_miss] Open this widget in ScriptWidget to prepare its photo snapshot"
        }
    }
}

/// Explicit app-owned scope. Missing settings allow no photos, including when
/// the OS grants the application full access. IDs are opaque UTF-8, not paths.
struct ScriptWidgetPhotoSelection: Equatable {
    static let fileName = "photos-access.v1.json"
    static let lockName = "ScriptWidget.PhotosAccess.v1"
    let assetIDs: [String]
    let albumIDs: [String]
    static let empty = Self(assetIDs: [], albumIDs: [])
    static func valid(_ ids: [String], maximum: Int) -> Bool {
        ids.count <= maximum && Set(ids.map { Data($0.utf8) }).count == ids.count && ids.allSatisfy {
            !$0.isEmpty && $0.utf8.count <= 1024 && !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }
    }
    var encoded: Data {
        (try? JSONSerialization.data(withJSONObject: ["formatVersion": 1, "assetIDs": assetIDs, "albumIDs": albumIDs], options: .sortedKeys)) ?? Data()
    }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.encoded == rhs.encoded }
    var identity: String { SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined() }
    static func load(container: URL) throws -> Self {
        guard let data = ScriptWidgetPackageFiles.read(root: container, relative: fileName, maximumBytes: 48 * 1024) else {
            var info = stat()
            if lstat(container.appendingPathComponent(fileName).path, &info) != 0 && errno == ENOENT { return .empty }
            throw ScriptWidgetPhotosError.unavailable
        }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(raw.keys) == ["formatVersion", "assetIDs", "albumIDs"],
              let version = raw["formatVersion"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(), version == 1,
              let assets = raw["assetIDs"] as? [String], let albums = raw["albumIDs"] as? [String],
              valid(assets, maximum: 24), valid(albums, maximum: 8) else { throw ScriptWidgetPhotosError.invalid }
        return .init(assetIDs: assets, albumIDs: albums)
    }
    func save(container: URL, replacing expected: Self) throws {
        guard Self.valid(assetIDs, maximum: 24), Self.valid(albumIDs, maximum: 8) else { throw ScriptWidgetPhotosError.invalid }
        let result = ScriptWidgetStorageLock.withExclusiveAccess(container: container, namespace: Self.lockName) {
            Result<Void, Error> {
                guard try Self.load(container: container) == expected else { throw ScriptWidgetPhotosError.changed }
                guard ScriptWidgetPackageFiles.write(encoded, root: container, relative: Self.fileName) else { throw ScriptWidgetPhotosError.unavailable }
            }
        }
        guard let result else { throw ScriptWidgetPhotosError.unavailable }; try result.get()
    }
}

struct ScriptWidgetPhotoQuery {
    let limit: Int
    let offset: Int
    let maxAgeSeconds: Double
    init(_ options: [String: Any]?) throws {
        let values = options ?? [:]
        guard Set(values.keys).isSubset(of: ["limit", "offset", "maxAgeSeconds"]) else { throw ScriptWidgetPhotosError.invalid }
        func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>, integer: Bool = false) throws -> Double {
            guard let value = values[key] else { return fallback }
            guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite,
                  range.contains(n.doubleValue), !integer || n.doubleValue.rounded() == n.doubleValue else { throw ScriptWidgetPhotosError.invalid }
            return n.doubleValue
        }
        limit = Int(try number("limit", 4, 1...4, integer: true))
        offset = Int(try number("offset", 0, 0...63, integer: true))
        maxAgeSeconds = try number("maxAgeSeconds", 3600, 0...86400)
    }
    var identity: String { "\(limit):\(offset)" }
}

struct ScriptWidgetPhotoReference: Codable, Equatable {
    let id: String
    let revision: Double
    let width: Int
    let height: Int
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id.utf8.elementsEqual(rhs.id.utf8) && lhs.revision == rhs.revision && lhs.width == rhs.width && lhs.height == rhs.height
    }
}
struct ScriptWidgetPhotoBytes: Codable {
    let reference: ScriptWidgetPhotoReference
    let jpeg: Data
    var valid: Bool {
        guard ScriptWidgetPhotoSelection.valid([reference.id], maximum: 1), reference.revision.isFinite,
              reference.width > 0, reference.height > 0, jpeg.count <= 128 * 1024,
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil), CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int, let h = props[kCGImagePropertyPixelHeight] as? Int else { return false }
        return w > 0 && h > 0 && w <= 768 && h <= 768
    }
    var object: [String: Any] { ["id": reference.id, "image": "data:image/jpeg;base64," + jpeg.base64EncodedString(), "width": reference.width, "height": reference.height] }
}
struct ScriptWidgetPhotoSnapshot: Codable {
    let formatVersion: Int
    let scope: String
    let query: String
    let authorization: String
    let references: [ScriptWidgetPhotoReference]
    let photos: [ScriptWidgetPhotoBytes]
    let fetchedAt: Double
    func matches(selection: ScriptWidgetPhotoSelection, query: ScriptWidgetPhotoQuery, status: String,
                 references: [ScriptWidgetPhotoReference], now: Date) -> Bool {
        formatVersion == 1 && scope == selection.identity && self.query == query.identity && authorization == status
            && self.references == references && references.count <= query.limit && photos.count <= references.count
            && Set(photos.map { Data($0.reference.id.utf8) }).count == photos.count
            && photos.allSatisfy { $0.valid && references.contains($0.reference) }
            && fetchedAt.isFinite && fetchedAt >= 0 && fetchedAt <= now.timeIntervalSince1970
            && now.timeIntervalSince1970 - fetchedAt <= 86400
    }
}

protocol ScriptWidgetPhotosProviding: AnyObject {
    func status() -> String
    func references(selection: ScriptWidgetPhotoSelection, query: ScriptWidgetPhotoQuery) throws -> [ScriptWidgetPhotoReference]
    func thumbnail(_ reference: ScriptWidgetPhotoReference, deadline: Date) -> ScriptWidgetPhotoBytes?
}

final class ScriptWidgetPhotosSystemProvider: ScriptWidgetPhotosProviding {
    func status() -> String { ScriptWidgetRuntimePhotos.systemAuthorizationStatus() }
    static func options(limit: Int = 64) -> PHFetchOptions {
        let options = PHFetchOptions(); options.fetchLimit = limit
        options.predicate = NSPredicate(format: "mediaType = %d AND hidden = NO", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return options
    }
    func references(selection: ScriptWidgetPhotoSelection, query: ScriptWidgetPhotoQuery) throws -> [ScriptWidgetPhotoReference] {
        guard ["authorized", "limited"].contains(status()) else { throw ScriptWidgetPhotosError.denied }
        var found: [Data: PHAsset] = [:]
        func add(_ assets: PHFetchResult<PHAsset>) {
            assets.enumerateObjects { asset, _, stop in
                if asset.mediaType == .image && !asset.isHidden { found[Data(asset.localIdentifier.utf8)] = asset }
                if found.count >= 64 { stop.pointee = true }
            }
        }
        add(PHAsset.fetchAssets(withLocalIdentifiers: selection.assetIDs, options: Self.options()))
        let albums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: selection.albumIDs, options: nil)
        albums.enumerateObjects { album, _, stop in
            if found.count < 64 { add(PHAsset.fetchAssets(in: album, options: Self.options(limit: 64 - found.count))) }
            if found.count >= 64 { stop.pointee = true }
        }
        let assets = found.values.sorted {
            let a = $0.creationDate ?? .distantPast, b = $1.creationDate ?? .distantPast
            return a == b ? $0.localIdentifier.utf8.lexicographicallyPrecedes($1.localIdentifier.utf8) : a > b
        }
        return assets.dropFirst(query.offset).prefix(query.limit).map { .init(id: $0.localIdentifier, revision: ($0.modificationDate ?? $0.creationDate ?? .distantPast).timeIntervalSince1970, width: $0.pixelWidth, height: $0.pixelHeight) }
    }
    func thumbnail(_ reference: ScriptWidgetPhotoReference, deadline: Date) -> ScriptWidgetPhotoBytes? {
        thumbnail(reference, deadline: deadline, maximumSize: 768)
    }
    func thumbnail(_ reference: ScriptWidgetPhotoReference, deadline: Date, maximumSize: Int) -> ScriptWidgetPhotoBytes? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [reference.id], options: nil).firstObject else { return nil }
        let options = PHImageRequestOptions(); options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat; options.resizeMode = .fast; options.version = .current
        let semaphore = DispatchSemaphore(value: 0), lock = NSLock(); var jpeg: Data?
        let manager = PHImageManager.default()
        let requestID = manager.requestImage(for: asset, targetSize: CGSize(width: maximumSize, height: maximumSize), contentMode: .aspectFit, options: options) { image, info in
            guard (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
            defer { semaphore.signal() }
            guard let image, (info?[PHImageCancelledKey] as? Bool) != true, info?[PHImageErrorKey] == nil else { return }
            #if os(macOS)
            var rect = CGRect(origin: .zero, size: image.size)
            guard let original = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
            let scale = min(1, Double(maximumSize) / Double(max(original.width, original.height)))
            let width = max(1, Int(Double(original.width) * scale)), height = max(1, Int(Double(original.height) * scale))
            guard let drawing = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            drawing.interpolationQuality = .high; drawing.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let cg = drawing.makeImage() else { return }
            #else
            // UIKit drawing normalizes UIImage orientation before metadata is
            // stripped. PhotoKit may deliver an image larger than targetSize.
            guard image.size.width > 0, image.size.height > 0 else { return }
            let scale = min(1, CGFloat(maximumSize) / max(image.size.width, image.size.height))
            let size = CGSize(width: max(1, floor(image.size.width * scale)), height: max(1, floor(image.size.height * scale)))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let cg = normalized.cgImage else { return }
            #endif
            // Re-encode pixels only, omitting EXIF, GPS and original filenames.
            guard cg.width <= maximumSize, cg.height <= maximumSize else { return }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return }
            CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary)
            if CGImageDestinationFinalize(destination), data.length <= 128 * 1024 { lock.lock(); jpeg = data as Data; lock.unlock() }
        }
        let timeout = min(0.7, max(0, deadline.timeIntervalSinceNow))
        guard semaphore.wait(timeout: .now() + timeout) == .success else { manager.cancelImageRequest(requestID); return nil }
        lock.lock(); defer { lock.unlock() }
        return jpeg.map { .init(reference: reference, jpeg: $0) }
    }
}

final class ScriptWidgetRuntimePhotos: NSObject, ScriptWidgetRuntimePhotosExports {
    private static let queue = DispatchQueue(label: "app.scriptwidget.photos", qos: .userInitiated)
    static func systemAuthorizationStatus() -> String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: "authorized"
        case .limited: "limited"
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .restricted: "restricted"
        @unknown default: "unavailable"
        }
    }
    private static func permitted(_ state: ScriptWidgetRunningState) -> Bool {
        guard state.previewStorage == nil, let manifest = state.package.readManifest(), manifest.permissions.contains(.photos) else { return false }
        return WidgetPackageManifestValidator.validate(manifest, package: state.package, checkEntryExists: false).isValid
    }
    private static func provider(_ state: ScriptWidgetRunningState) -> any ScriptWidgetPhotosProviding {
        #if DEBUG
        if let value = state.photosProviderForTesting { return value }
        #endif
        return ScriptWidgetPhotosSystemProvider()
    }
    static func isAvailable() -> Bool { guard let state = JSContext.current()?.scriptWidgetRunningState else { return false }; return permitted(state) && state.isCurrentExecution }
    static func authorizationStatus() -> String { guard let state = JSContext.current()?.scriptWidgetRunningState, permitted(state), state.isCurrentExecution else { return "undeclared" }; return provider(state).status() }
    static func requestSystemAuthorization(completion: @escaping (Bool) -> Void) {
        #if !IsWidgetTarget
        DispatchQueue.main.async {
            guard Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") is String else { completion(false); return }
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in DispatchQueue.main.async { completion(status == .authorized || status == .limited) } }
        }
        #else
        completion(["authorized", "limited"].contains(systemAuthorizationStatus()))
        #endif
    }
    static func requestAuthorization() -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state, permitted(state), state.isCurrentExecution else { reject.call(withArguments: [ScriptWidgetPhotosError.denied.localizedDescription]); return }
            if state.isTimelineProjection || state.isLiveActivityPresentation { resolve.call(withArguments: [["authorized", "limited"].contains(provider(state).status())]); return }
            guard state.executionSession.registerDataQuery() else { reject.call(withArguments: ["[query_limit] Too many system data queries"]); return }
            requestSystemAuthorization { granted in
                state.executionSession.callbackQueue.async {
                    if state.isCurrentExecution && permitted(state) { resolve.call(withArguments: [granted]) }
                }
            }
        }
    }
    static func items(_ options: [String: Any]?) -> ScriptWidgetRuntimePromise {
        let state = JSContext.current()?.scriptWidgetRunningState
        return ScriptWidgetRuntimePromise { resolve, reject in
            guard let state, permitted(state), state.isCurrentExecution, let snapshot = state.executionSnapshot else { reject.call(withArguments: [ScriptWidgetPhotosError.denied.localizedDescription]); return }
            let query: ScriptWidgetPhotoQuery
            do { query = try .init(options) } catch { reject.call(withArguments: [ScriptWidgetPhotosError.invalid.localizedDescription]); return }
            guard state.executionSession.registerDataQuery() else { reject.call(withArguments: ["[query_limit] Too many system data queries"]); return }
            queue.async {
                let store = snapshot.context.defaults, container = snapshot.context.container
                let key = "ScriptWidget.PhotosCache.v1." + SHA256.hash(data: Data(state.storageNamespace.utf8)).map { String(format: "%02x", $0) }.joined()
                do {
                    let source = provider(state), status = source.status()
                    func validate() throws {
                        guard state.isCurrentExecution, permitted(state), ["authorized", "limited"].contains(source.status()), source.status() == status else { throw ScriptWidgetPhotosError.denied }
                    }
                    try validate()
                    let selection = try ScriptWidgetPhotoSelection.load(container: container)
                    guard !selection.assetIDs.isEmpty || !selection.albumIDs.isEmpty else { throw ScriptWidgetPhotosError.denied }
                    let references = try source.references(selection: selection, query: query), now = Date()
                    guard references.count <= query.limit, Set(references.map { Data($0.id.utf8) }).count == references.count,
                          references.allSatisfy({ ScriptWidgetPhotoSelection.valid([$0.id], maximum: 1) && $0.revision.isFinite && $0.width > 0 && $0.height > 0 }) else { throw ScriptWidgetPhotosError.unavailable }
                    var cached: ScriptWidgetPhotoSnapshot?
                    if let bytes = try? store.readValue(forKey: key) as? Data, bytes.count <= 1024 * 1024,
                       let decoded = try? JSONDecoder().decode(ScriptWidgetPhotoSnapshot.self, from: bytes), decoded.matches(selection: selection, query: query, status: status, references: references, now: now) { cached = decoded }
                    let readOnly = state.isTimelineProjection || state.isLiveActivityPresentation
                    var value: ScriptWidgetPhotoSnapshot
                    let fromCache: Bool
                    if let cached, readOnly || now.timeIntervalSince1970 - cached.fetchedAt <= min(query.maxAgeSeconds, cached.photos.count < references.count ? 60 : query.maxAgeSeconds) { value = cached; fromCache = true }
                    else {
                        guard !readOnly else { throw ScriptWidgetPhotosError.cacheMiss }
                        let deadline = Date().addingTimeInterval(2.8)
                        var photos: [ScriptWidgetPhotoBytes] = []
                        for reference in references {
                            try validate()
                            if let image = source.thumbnail(reference, deadline: deadline), image.valid { photos.append(image) }
                        }
                        value = .init(formatVersion: 1, scope: selection.identity, query: query.identity, authorization: status, references: references, photos: photos, fetchedAt: now.timeIntervalSince1970)
                        fromCache = false
                    }
                    try validate()
                    guard try ScriptWidgetPhotoSelection.load(container: container) == selection,
                          try source.references(selection: selection, query: query) == references else { throw ScriptWidgetPhotosError.changed }
                    if !readOnly {
                        let bytes = try JSONEncoder().encode(value)
                        guard bytes.count <= 1024 * 1024 else { throw ScriptWidgetPhotosError.unavailable }
                        try store.writeValue(bytes, forKey: key)
                    }
                    let response: [String: Any] = ["status": value.photos.isEmpty && !references.isEmpty ? "unavailable" : "ready", "items": value.photos.map(\.object), "unavailableCount": references.count - value.photos.count, "fetchedAt": ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: value.fetchedAt)), "source": fromCache ? "cache" : "system", "stale": now.timeIntervalSince1970 - value.fetchedAt > query.maxAgeSeconds]
                    state.executionSession.callbackQueue.async {
                        guard state.isCurrentExecution else { return }
                        do {
                            try validate()
                            guard try ScriptWidgetPhotoSelection.load(container: container) == selection,
                                  try source.references(selection: selection, query: query) == references else { throw ScriptWidgetPhotosError.changed }
                            resolve.call(withArguments: [response])
                        } catch { try? store.removeValue(forKey: key); reject.call(withArguments: [ScriptWidgetPhotosError.changed.localizedDescription]) }
                    }
                } catch {
                    try? store.removeValue(forKey: key)
                    let message = (error as? ScriptWidgetPhotosError)?.localizedDescription ?? ScriptWidgetPhotosError.unavailable.localizedDescription
                    state.executionSession.callbackQueue.async { if state.isCurrentExecution { reject.call(withArguments: [message]) } }
                }
            }
        }
    }
}

#if !IsWidgetTarget
import SwiftUI
import WidgetKit

@MainActor
final class ScriptWidgetPhotosAccessModel: ObservableObject {
    struct Choice: Identifiable { let id: String; let title: String }
    @Published var assetIDs: [String] = []
    @Published var albumIDs: [String] = []
    @Published private(set) var assets: [Choice] = []
    @Published private(set) var albums: [Choice] = []
    @Published private(set) var message: String?
    @Published private(set) var loading = false
    private var original: ScriptWidgetPhotoSelection?
    private let container: URL?
    init(container: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.everettjf.scriptwidget")) { self.container = container }
    var draft: ScriptWidgetPhotoSelection { .init(assetIDs: assetIDs, albumIDs: albumIDs) }
    var hasChanges: Bool { original != draft }
    func reload() async {
        guard !loading else { return }; loading = true; defer { loading = false }
        do {
            guard let container else { throw ScriptWidgetPhotosError.unavailable }
            let stored = try ScriptWidgetPhotoSelection.load(container: container)
            if original == nil || !hasChanges { original = stored; assetIDs = stored.assetIDs; albumIDs = stored.albumIDs }
            let result = await Task.detached { () -> ([Choice], [Choice]) in
                guard ["authorized", "limited"].contains(ScriptWidgetRuntimePhotos.systemAuthorizationStatus()) else { return ([], []) }
                var assets: [Choice] = [], albums: [Choice] = []
                let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
                PHAsset.fetchAssets(with: ScriptWidgetPhotosSystemProvider.options()).enumerateObjects { asset, index, _ in
                    assets.append(.init(id: asset.localIdentifier, title: asset.creationDate.map(formatter.string) ?? "Photo \(index + 1)"))
                }
                let options = PHFetchOptions(); options.fetchLimit = 32
                PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).enumerateObjects { album, _, _ in
                    albums.append(.init(id: album.localIdentifier, title: String((album.localizedTitle ?? "Untitled album").prefix(256))))
                }
                return (assets, albums)
            }.value
            assets = result.0; albums = result.1; message = nil
        } catch { message = "Photo selection could not be loaded. Access remains closed." }
    }
    func discardAndReload() async { original = nil; await reload() }
    func selected(_ id: String, album: Bool) -> Bool { (album ? albumIDs : assetIDs).contains { $0.utf8.elementsEqual(id.utf8) } }
    func select(_ id: String, album: Bool, enabled: Bool) {
        var ids = album ? albumIDs : assetIDs
        ids.removeAll { $0.utf8.elementsEqual(id.utf8) }
        if enabled { ids.append(id) }
        guard ScriptWidgetPhotoSelection.valid(ids, maximum: album ? 8 : 24) else { return }
        if album { albumIDs = ids } else { assetIDs = ids }
    }
    func save() {
        do {
            guard let container, let original else { throw ScriptWidgetPhotosError.unavailable }
            try draft.save(container: container, replacing: original)
            self.original = draft; message = "Photo selection saved. Open the widget in ScriptWidget to prepare its photos."
            WidgetCenter.shared.reloadAllTimelines()
        } catch { message = "Photo selection changed or could not be saved. Reload before saving again." }
    }
}

@MainActor
private struct ScriptWidgetPhotoChoicePreview: View {
    let id: String
    @State private var image: CGImage?
    var body: some View {
        Group {
            if let image { Image(decorative: image, scale: 1).resizable().scaledToFill() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }.frame(width: 56, height: 40).clipped().accessibilityHidden(true)
            .task(id: id) {
                let picture = await Task.detached { () -> CGImage? in
                    guard ["authorized", "limited"].contains(ScriptWidgetRuntimePhotos.systemAuthorizationStatus()),
                          let bytes = ScriptWidgetPhotosSystemProvider().thumbnail(.init(id: id, revision: 0, width: 1, height: 1), deadline: Date().addingTimeInterval(0.7), maximumSize: 128),
                          let source = CGImageSourceCreateWithData(bytes.jpeg as CFData, nil) else { return nil }
                    return CGImageSourceCreateImageAtIndex(source, 0, nil)
                }.value
                if !Task.isCancelled && ["authorized", "limited"].contains(ScriptWidgetRuntimePhotos.systemAuthorizationStatus()) { image = picture }
            }
    }
}

@MainActor
struct PhotosAccessSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = ScriptWidgetPhotosAccessModel()
    @State private var status = ScriptWidgetRuntimePhotos.systemAuthorizationStatus()
    @State private var requesting = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Photos for Widgets", systemImage: "photo.on.rectangle").font(.headline)
            Text("Choose individual photos or albums. Only selected sources are available to widgets that declare photos. No photos are selected by default.").font(.footnote).foregroundStyle(.secondary)
            if ["authorized", "limited"].contains(status) {
                if status == "limited" { Text("Limited system access: only photos allowed in system settings are available. Albums may be unavailable.").font(.footnote).foregroundStyle(.secondary) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        Text("Recent photos (up to 64)").font(.subheadline.bold())
                        ForEach(model.assets) { photo in
                            HStack {
                                ScriptWidgetPhotoChoicePreview(id: photo.id)
                                Toggle(photo.title, isOn: Binding(get: { model.selected(photo.id, album: false) }, set: { model.select(photo.id, album: false, enabled: $0) })).lineLimit(2)
                                    .disabled(!model.selected(photo.id, album: false) && model.assetIDs.count >= 24)
                            }
                        }
                        Text("Albums (up to 32)").font(.subheadline.bold())
                        ForEach(model.albums) { album in
                            Toggle(album.title, isOn: Binding(get: { model.selected(album.id, album: true) }, set: { model.select(album.id, album: true, enabled: $0) }))
                                .disabled(!model.selected(album.id, album: true) && model.albumIDs.count >= 8)
                        }
                    }
                }.frame(maxHeight: 240)
                Text("\(model.assetIDs.count) photos · \(model.albumIDs.count) albums selected. At most 64 candidates and four thumbnails per query. Cloud-only photos must be downloaded in Photos first.").font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Save Photo Selection") { model.save() }.disabled(model.loading || !model.hasChanges)
                    Button("Reload Selection") { Task { await model.discardAndReload() } }.disabled(model.loading)
                    Button("Select None") { model.assetIDs = []; model.albumIDs = [] }
                }
            } else {
                Button(requesting ? "Requesting Access…" : "Allow Photos Access") {
                    requesting = true
                    ScriptWidgetRuntimePhotos.requestSystemAuthorization { _ in
                        requesting = false; status = ScriptWidgetRuntimePhotos.systemAuthorizationStatus()
                        Task { await model.reload() }
                    }
                }.disabled(requesting || status == "restricted")
                if status == "denied" { Text("Review Photos access in system privacy settings, then return here.").font(.footnote) }
            }
            if let message = model.message { Text(message).font(.footnote).accessibilityLabel(message) }
        }.task(id: scenePhase) { if scenePhase == .active { status = ScriptWidgetRuntimePhotos.systemAuthorizationStatus(); await model.reload() } }
    }
}
struct PhotosAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form { Section("Photos") { PhotosAccessSettingsView() } }.navigationTitle("Data Access")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }
}
#endif
