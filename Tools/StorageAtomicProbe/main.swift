// Executable acceptance probe compiled together with the production coordinator.
import Foundation
import Darwin

let arguments = CommandLine.arguments
if arguments.count < 5 { exit(64) }
let mode = arguments[1], root = URL(fileURLWithPath: arguments[2]), domain = arguments[3]
guard let store = UserDefaults(suiteName: domain), let iterations = Int(arguments[4]), iterations >= 0, iterations <= 10_000 else { exit(64) }
let namespace = "script.counter."
let publicationLocation = String(repeating: "a", count: 64)
let publicationDestination = root.appendingPathComponent("installed")
func directoryReceipt(_ path: URL) -> ScriptWidgetStoragePublicationReceipt? {
    let fd = open(path.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { return nil }
    defer { close(fd) }
    var info = stat()
    guard fstat(fd, &info) == 0 else { return nil }
    return .init(device: UInt64(UInt32(bitPattern: info.st_dev)), inode: info.st_ino)
}
func publicationState(_ receipt: ScriptWidgetStoragePublicationReceipt) throws -> ScriptWidgetStoragePublicationState {
    if let actual = directoryReceipt(publicationDestination) { return actual == receipt ? .matching : .different }
    var info = stat()
    if lstat(publicationDestination.path, &info) != 0 && errno == ENOENT { return .absent }
    throw ScriptWidgetStorageNamespaceError.unavailable
}
// Registry contention is an explicit transient result (200 ms lock budget).
// Simultaneous first-launch probes retry that result, not validation failures.
func retryBusy<T>(_ operation: () throws -> T) throws -> T {
    let deadline = Date().addingTimeInterval(10)
    while true {
        do { return try operation() }
        catch ScriptWidgetStorageNamespaceError.unavailable {
            guard Date() < deadline else { throw ScriptWidgetStorageNamespaceError.unavailable }
            usleep(2_000)
        }
    }
}
func relocationState(_ name: String, _ receipt: ScriptWidgetStoragePublicationReceipt) throws -> ScriptWidgetStoragePublicationState {
    let path = root.appendingPathComponent(name)
    if let actual = directoryReceipt(path) { return actual == receipt ? .matching : .different }
    var info = stat()
    if lstat(path.path, &info) != 0 && errno == ENOENT { return .absent }
    throw ScriptWidgetStorageNamespaceError.unavailable
}
func capacityPayload(owner: Int, key: Int) -> String {
    var state: UInt32 = UInt32(owner * 8 + key + 1)
    var bytes = [UInt8](); bytes.reserveCapacity(ScriptWidgetAtomicPreferences.maximumValueBytes)
    for _ in 0..<ScriptWidgetAtomicPreferences.maximumValueBytes {
        state = state &* 1_664_525 &+ 1_013_904_223
        bytes.append(33 + UInt8((state >> 16) % 90))
    }
    return String(decoding: bytes, as: UTF8.self)
}
if mode == "capacity-write" || mode == "capacity-read" {
    guard (1...8).contains(iterations) else { exit(64) }
    var report: [String: Any] = ["mode": mode, "ownersRequested": iterations,
        "bytesPerValue": ScriptWidgetAtomicPreferences.maximumValueBytes, "keysPerOwner": 8,
        "signedAppGroup": false, "os": ProcessInfo.processInfo.operatingSystemVersionString]
    var timings: [Double] = [], verified = 0, failure: String?
    do {
        if mode == "capacity-write" {
            store.removePersistentDomain(forName: domain); _ = store.synchronize()
            _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: [], inventoryIsComplete: true, container: root, defaults: store)
        }
        for ownerIndex in 0..<iterations {
            let prefix: String
            if mode == "capacity-write" {
                prefix = try ScriptWidgetStorageNamespaces.registerFresh(name: "Capacity-\(ownerIndex)", container: root, defaults: store).namespace
            } else {
                prefix = try ScriptWidgetStorageNamespaces.namespace(for: "Capacity-\(ownerIndex)", container: root, defaults: store)
            }
            for keyIndex in 0..<8 {
                let key = "value-\(keyIndex)", expected = capacityPayload(owner: ownerIndex, key: keyIndex)
                let start = DispatchTime.now().uptimeNanoseconds
                if mode == "capacity-write" {
                    guard ScriptWidgetAtomicPreferences.compareAndSetString(container: root, defaults: store, namespace: prefix,
                        key: key, expected: "", value: expected, canStore: { preferences, value in
                            (try? ScriptWidgetStorageNamespaces.fitsBudget(namespace: prefix, defaults: preferences, replacing: [key: value])) == true
                        }) else { throw ScriptWidgetStorageNamespaceError.unavailable }
                }
                guard store.synchronize(), store.data(forKey: ScriptWidgetStorageNamespaces.registryKey) != nil,
                      store.string(forKey: prefix + key) == expected else { throw ScriptWidgetStorageNamespaceError.invalidRegistry }
                timings.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                verified += 1
            }
        }
    } catch {
        failure = (error as? ScriptWidgetStorageNamespaceError).map { String(describing: $0) } ?? "unexpected"
    }
    let sorted = timings.sorted()
    report["passed"] = failure == nil; report["failure"] = failure ?? ""
    report["valuesVerified"] = verified; report["payloadBytesVerified"] = verified * ScriptWidgetAtomicPreferences.maximumValueBytes
    report["p50Milliseconds"] = sorted.isEmpty ? 0 : sorted[(sorted.count - 1) / 2]
    report["p95Milliseconds"] = sorted.isEmpty ? 0 : sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
    report["maximumMilliseconds"] = sorted.last ?? 0
    print(String(decoding: try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
} else if mode.hasPrefix("replacement-crash-") {
    do {
        _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: [], inventoryIsComplete: true, container: root, defaults: store)
        let initial = root.appendingPathComponent("gallery-initial")
        try FileManager.default.createDirectory(at: initial, withIntermediateDirectories: false)
        guard let initialReceipt = directoryReceipt(initial) else { exit(1) }
        let owner = try ScriptWidgetStorageNamespaces.publishFresh(name: "counter", location: publicationLocation, receipt: initialReceipt,
            galleryID: "dev.scriptwidget.probe-gallery", container: root, defaults: store,
            inspect: { try relocationState("counter", $0) }, publish: { _ in
                try FileManager.default.moveItem(at: initial, to: root.appendingPathComponent("counter"))
            })
        store.set("preserved", forKey: owner.namespace + "private"); _ = store.synchronize()
        let binding = try ScriptWidgetStorageNamespaces.boundDirectory(name: "counter", role: .source, location: publicationLocation,
            receipt: initialReceipt, container: root, defaults: store)
        let stagingName = ScriptWidgetStorageNamespaces.replacementPrefix + UUID().uuidString.lowercased()
        let staging = root.appendingPathComponent(stagingName)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        guard let receipt = directoryReceipt(staging) else { exit(1) }
        let proof = ["prefix": owner.namespace, "ownerID": owner.id]
        try JSONSerialization.data(withJSONObject: proof).write(to: root.appendingPathComponent("replacement-proof.json"), options: .atomic)
        _ = try ScriptWidgetStorageNamespaces.replaceGallerySource(source: binding, staging: stagingName, receipt: receipt,
            galleryID: "dev.scriptwidget.probe-gallery", container: root, defaults: store,
            inspect: { directoryReceipt(root.appendingPathComponent($0)) }, swap: {
                if mode.hasSuffix("after") {
                    guard renameatx_np(AT_FDCWD, staging.path, AT_FDCWD, root.appendingPathComponent("counter").path, UInt32(RENAME_SWAP)) == 0 else { exit(1) }
                }
                _exit(86)
            })
        exit(1)
    } catch { exit(1) }
} else if mode == "replacement-recover" {
    do {
        let proof = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("replacement-proof.json"))) as! [String: String]
        let result = try ScriptWidgetStorageNamespaces.recoverReplacement(location: publicationLocation, container: root, defaults: store,
            inspect: { directoryReceipt(root.appendingPathComponent($0)) })
        guard try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store) == proof["prefix"],
              store.string(forKey: proof["prefix"]! + "private") == "preserved",
              let binding = try ScriptWidgetStorageNamespaces.gallerySource(itemID: "dev.scriptwidget.probe-gallery", location: publicationLocation, container: root, defaults: store),
              binding.ownerID == proof["ownerID"], binding.receipt == directoryReceipt(root.appendingPathComponent("counter")) else { exit(1) }
        let cleanup = try ScriptWidgetStorageNamespaces.pendingCleanup(location: publicationLocation, container: root, defaults: store)
        guard cleanup.count == 1, cleanup[0].receipt == directoryReceipt(root.appendingPathComponent(cleanup[0].name)) else { exit(1) }
        switch result {
        case .committed: print("committed")
        case .rolledBack: print("rolledBack")
        case .none: exit(1)
        }
    } catch { exit(1) }
} else if mode.hasPrefix("relocation-crash-") {
    do {
        _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: ["counter"], inventoryIsComplete: true, container: root, defaults: store)
        let prefix = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        store.set("preserved", forKey: prefix + "private"); _ = store.synchronize()
        let source = root.appendingPathComponent("counter")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: false)
        guard let receipt = directoryReceipt(source) else { exit(1) }
        try ScriptWidgetStorageNamespaces.bindInventoriedSource(name: "counter", location: publicationLocation, receipt: receipt, container: root, defaults: store)
        let binding = try ScriptWidgetStorageNamespaces.boundDirectory(name: "counter", role: .source, location: publicationLocation,
            receipt: receipt, container: root, defaults: store)
        let deleting = mode.contains("delete")
        let destination = deleting ? ScriptWidgetStorageNamespaces.retiredDirectoryPrefix + binding.ownerID : "renamed-counter"
        let proof = ["prefix": prefix, "destination": destination, "deleting": deleting ? "yes" : "no"]
        try JSONSerialization.data(withJSONObject: proof).write(to: root.appendingPathComponent("relocation-proof.json"), options: .atomic)
        _ = try ScriptWidgetStorageNamespaces.relocate(source: binding, destination: destination, deleting: deleting,
            container: root, defaults: store, inspect: relocationState, move: {
                if mode.hasSuffix("after") { try FileManager.default.moveItem(at: source, to: root.appendingPathComponent(destination)) }
                _exit(86)
            })
        exit(1)
    } catch { exit(1) }
} else if mode == "relocation-recover" {
    do {
        let proof = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("relocation-proof.json"))) as! [String: String]
        let prefix = proof["prefix"]!, destination = proof["destination"]!, deleting = proof["deleting"] == "yes"
        let recovered = try ScriptWidgetStorageNamespaces.recoverRelocation(location: publicationLocation, container: root, defaults: store, inspect: relocationState)
        guard store.string(forKey: prefix + "private") == "preserved", store.string(forKey: namespace + "count") == "0" else { exit(1) }
        switch recovered {
        case .rolledBack:
            guard try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store) == prefix,
                  directoryReceipt(root.appendingPathComponent("counter")) != nil else { exit(1) }
            print("rolledBack")
        case .committed(let source, let actual, let wasDeleting):
            guard source == "counter", actual == destination, wasDeleting == deleting, directoryReceipt(root.appendingPathComponent(destination)) != nil else { exit(1) }
            if deleting {
                let fresh = try ScriptWidgetStorageNamespaces.registerFresh(name: "counter", container: root, defaults: store)
                guard fresh.namespace != prefix, store.object(forKey: fresh.namespace + "private") == nil else { exit(1) }
            } else {
                guard try ScriptWidgetStorageNamespaces.namespace(for: destination, container: root, defaults: store) == prefix else { exit(1) }
            }
            print("committed")
        case .none: exit(1)
        }
    } catch { exit(1) }
} else if mode == "publication-crash-before" || mode == "publication-crash-after" {
    do {
        _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: ["counter"], inventoryIsComplete: true, container: root, defaults: store)
        let previous = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        store.set("preserved", forKey: previous + "private")
        guard store.synchronize() else { exit(1) }
        let staging = root.appendingPathComponent("prepared")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
        guard let receipt = directoryReceipt(staging) else { exit(1) }
        _ = try ScriptWidgetStorageNamespaces.publishFresh(name: "counter", location: publicationLocation, receipt: receipt,
            container: root, defaults: store, inspect: publicationState, publish: { owner in
                let data = try JSONSerialization.data(withJSONObject: ["previous": previous, "reserved": owner.id], options: .sortedKeys)
                try data.write(to: root.appendingPathComponent("publication-proof.json"), options: .atomic)
                if mode == "publication-crash-after" { try FileManager.default.moveItem(at: staging, to: publicationDestination) }
                // Exit without unwinding or running cleanup, as a killed host.
                _exit(86)
            })
        exit(1)
    } catch { fputs("Publication crash probe setup failed\n", stderr); exit(1) }
} else if mode == "publication-recover" {
    do {
        let proof = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("publication-proof.json"))) as! [String: String]
        do { _ = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store); exit(1) }
        catch ScriptWidgetStorageNamespaceError.unavailable {} catch { exit(1) }
        let recovered = try ScriptWidgetStorageNamespaces.recoverInstallation(location: publicationLocation, container: root, defaults: store) { name, receipt in
            guard name == "counter" else { throw ScriptWidgetStorageNamespaceError.conflict }
            return try publicationState(receipt)
        }
        let current = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        let previous = proof["previous"]!
        let expectedID = proof["reserved"]!
        let outcome: String
        switch recovered {
        case .committed(let owner):
            guard owner.id == expectedID, current == owner.namespace, current != previous,
                  store.object(forKey: current + "private") == nil else { exit(1) }
            outcome = "committed"
        case .rolledBack:
            guard current == previous else { exit(1) }
            outcome = "rolledBack"
        case .none: exit(1)
        }
        guard store.string(forKey: previous + "private") == "preserved",
              store.object(forKey: ScriptWidgetStorageNamespaces.installationKey) == nil else { exit(1) }
        print(outcome)
    } catch { fputs("Publication recovery probe failed\n", stderr); exit(1) }
} else if mode == "publication-race-reset" {
    do {
        store.removePersistentDomain(forName: domain)
        _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: ["counter"], inventoryIsComplete: true, container: root, defaults: store)
        let previous = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        store.set("preserved", forKey: previous + "private")
        guard store.synchronize() else { exit(1) }
        try Data(previous.utf8).write(to: root.appendingPathComponent("previous"))
    } catch { exit(1) }
} else if mode == "read-publication-race" {
    do {
        let index = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: [], inventoryIsComplete: true, container: root, defaults: store)
        let prefix = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        let previous = try String(contentsOf: root.appendingPathComponent("previous"), encoding: .utf8)
        guard index.owners.count == 2, index.owners.filter({ $0.active }).count == 1, prefix != previous,
              store.object(forKey: prefix + "private") == nil, store.string(forKey: previous + "private") == "preserved",
              store.object(forKey: ScriptWidgetStorageNamespaces.installationKey) == nil else { exit(1) }
        print("isolated")
    } catch { exit(1) }
} else if mode == "reset" || mode == "reset-namespaced" {
    store.removePersistentDomain(forName: domain)
    if mode == "reset-namespaced" { store.set("0", forKey: namespace + "count") }
    _ = store.synchronize()
} else if mode == "increment" || mode == "increment-unsafe" || mode == "increment-namespaced" || mode == "publication-race" {
    try! Data().write(to: root.appendingPathComponent("ready-\(ProcessInfo.processInfo.processIdentifier)"))
    let deadline = Date().addingTimeInterval(10)
    while !FileManager.default.fileExists(atPath: root.appendingPathComponent("start").path) {
        if Date() > deadline { exit(1) }
        usleep(1_000)
    }
    if mode == "publication-race" {
        do {
            let staging = root.appendingPathComponent("prepared-\(ProcessInfo.processInfo.processIdentifier)")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
            guard let receipt = directoryReceipt(staging) else { exit(1) }
            var outcome: String
            do {
                let owner = try ScriptWidgetStorageNamespaces.publishFresh(name: "counter", location: publicationLocation, receipt: receipt,
                    container: root, defaults: store, inspect: publicationState, publish: { _ in
                        try FileManager.default.moveItem(at: staging, to: publicationDestination)
                    })
                outcome = "committed:" + owner.id
            } catch ScriptWidgetStorageNamespaceError.conflict { outcome = "conflict" }
            catch ScriptWidgetStorageNamespaceError.unavailable { outcome = "busy" }
            try Data(outcome.utf8).write(to: root.appendingPathComponent("publication-\(ProcessInfo.processInfo.processIdentifier)"))
            exit(0)
        } catch { exit(1) }
    }
    var targetNamespace = namespace
    if mode == "increment-namespaced" {
        do {
            _ = try retryBusy { try ScriptWidgetStorageNamespaces.bootstrap(existingNames: ["counter", "counter.child"], inventoryIsComplete: true, container: root, defaults: store) }
            targetNamespace = try retryBusy { try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store) }
            let worker = try retryBusy { try ScriptWidgetStorageNamespaces.registerFresh(name: "Worker-\(ProcessInfo.processInfo.processIdentifier)", container: root, defaults: store) }
            guard ScriptWidgetAtomicPreferences.compareAndSetString(container: root, defaults: store, namespace: worker.namespace, key: "private", expected: "", value: String(ProcessInfo.processInfo.processIdentifier)) else { exit(1) }
            try Data(targetNamespace.utf8).write(to: root.appendingPathComponent("owner-\(ProcessInfo.processInfo.processIdentifier)"))
        } catch {
            let reason = (error as? ScriptWidgetStorageNamespaceError).map { String(describing: $0) } ?? "unexpected error"
            fputs("Namespace migration probe failed: \(reason)\n", stderr); exit(1)
        }
    }
    for _ in 0..<iterations {
        var committed = false
        for _ in 0..<1_000 {
            _ = store.synchronize()
            let expected = store.string(forKey: targetNamespace + "count") ?? ""
            let next = String((Int(expected) ?? 0) + 1)
            if mode == "increment-unsafe" {
                // Negative control deliberately recreates an uncoordinated RMW.
                usleep(2_000)
                store.set(next, forKey: targetNamespace + "count")
                _ = store.synchronize()
                committed = true
                break
            }
            if ScriptWidgetAtomicPreferences.compareAndSetString(container: root, defaults: store, namespace: targetNamespace, key: "count", expected: expected, value: next) { committed = true; break }
        }
        if !committed { exit(1) }
    }
} else if mode == "read" {
    _ = store.synchronize()
    print(store.string(forKey: namespace + "count") ?? "0")
} else if mode == "read-namespaced" {
    do {
        let index = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: [], inventoryIsComplete: true, container: root, defaults: store)
        let prefix = try ScriptWidgetStorageNamespaces.namespace(for: "counter", container: root, defaults: store)
        let workers = index.owners.filter { $0.name.hasPrefix("Worker-") }
        let values = workers.compactMap { store.string(forKey: $0.namespace + "private") }
        let result: [String: Any] = ["count": Int(store.string(forKey: prefix + "count") ?? "-1") ?? -1,
                                     "owners": index.owners.count, "workerValues": Set(values).count,
                                     "legacy": store.string(forKey: namespace + "count") ?? "missing"]
        print(String(decoding: try JSONSerialization.data(withJSONObject: result, options: .sortedKeys), as: UTF8.self))
    } catch { exit(1) }
} else { exit(64) }
