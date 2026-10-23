import Foundation
import Darwin

// Observe entry into the locked transaction without changing the runtime's
// timeout or interpreting every false result as contention.
final class ObservedProbeBackend: ScriptWidgetStorageBackend {
    let base: any ScriptWidgetStorageBackend
    var enteredLock = false
    init(_ base: any ScriptWidgetStorageBackend) { self.base = base }
    func readValue(forKey key: String) throws -> Any? { try base.readValue(forKey: key) }
    func writeValue(_ value: Any, forKey key: String) throws { try base.writeValue(value, forKey: key) }
    func removeValue(forKey key: String) throws { try base.removeValue(forKey: key) }
    func legacyValues() throws -> [String: Any] { try base.legacyValues() }
    func values(in namespace: String) throws -> [(String, Any)] { try base.values(in: namespace) }
    func mutateValues(in namespace: String, operation: (any ScriptWidgetStorageBackend) throws -> Bool) throws -> Bool {
        try base.mutateValues(in: namespace, operation: operation)
    }
    func synchronize() -> Bool { enteredLock = true; return base.synchronize() }
}

let arguments = CommandLine.arguments
if arguments.count != 4 { exit(2) }
let mode = arguments[1], root = URL(fileURLWithPath: arguments[2]), expected = Int(arguments[3]) ?? 0
func payload(_ owner: Int, _ key: Int) -> String {
    var state = UInt32(owner * 8 + key + 1), bytes = [UInt8]()
    bytes.reserveCapacity(ScriptWidgetAtomicPreferences.maximumValueBytes)
    for _ in 0..<ScriptWidgetAtomicPreferences.maximumValueBytes {
        state = state &* 1_664_525 &+ 1_013_904_223
        bytes.append(33 + UInt8((state >> 16) % 90))
    }
    return String(decoding: bytes, as: UTF8.self)
}
func emit(_ report: [String: Any]) throws {
    print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), as: UTF8.self))
}
func fail(_ reason: String, committed: Int = 0, lockRejections: Int = 0, operationStarted: Bool = false) -> Never {
    let report: [String: Any] = ["mode": mode, "reason": reason, "committed": committed, "lockRejections": lockRejections, "operationStarted": operationStarted]
    let data = (try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])) ?? Data()
    fputs(String(decoding: data, as: UTF8.self) + "\n", stderr)
    exit(3)
}
do {
    let legacy = UserDefaults(suiteName: "app.scriptwidget.file-probe." + root.lastPathComponent)!
    let backend = try ScriptWidgetFileStorageBackend(container: root, legacy: legacy)
    _ = try ScriptWidgetStorageNamespaces.bootstrap(existingNames: [], inventoryIsComplete: true, container: root, defaults: backend)
    func namespace(_ name: String) throws -> String {
        try ScriptWidgetStorageNamespaces.namespace(for: name, container: root, defaults: backend)
    }
    if mode == "capacity-write" || mode == "capacity-read" {
        var times: [Double] = [], verified = 0
        if mode == "capacity-write" {
            for index in 0..<4 {
                _ = try ScriptWidgetStorageNamespaces.registerFresh(name: "Capacity-\(index)", container: root, defaults: backend)
            }
        }
        let prefixes = try (0..<4).map { try namespace("Capacity-\($0)") }
        for ownerIndex in 0..<4 {
            for keyIndex in 0..<8 {
                let key = "key-\(keyIndex)", value = payload(ownerIndex, keyIndex)
                let start = DispatchTime.now().uptimeNanoseconds
                if mode == "capacity-write" {
                    guard ScriptWidgetAtomicPreferences.compareAndSetString(container: root, defaults: backend,
                        namespace: prefixes[ownerIndex], key: key, expected: "", value: value, canStore: { staged, replacement in
                            (try? ScriptWidgetStorageNamespaces.fitsBudget(namespace: prefixes[ownerIndex], defaults: staged, replacing: [key: replacement])) == true
                        }) else { fail("capacity-write-failed") }
                }
                guard try backend.readValue(forKey: prefixes[ownerIndex] + key) as? String == value else { fail("capacity-read-mismatch") }
                times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                verified += 1
            }
        }
        let sorted = times.sorted()
        try emit(["mode": mode, "backend": "native-files+identity-coordinator", "passed": verified == 32, "valuesVerified": verified,
                  "payloadBytesVerified": verified * ScriptWidgetAtomicPreferences.maximumValueBytes,
                  "p50Milliseconds": sorted[(sorted.count - 1) / 2],
                  "p95Milliseconds": sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1],
                  "maximumMilliseconds": sorted.last!, "os": ProcessInfo.processInfo.operatingSystemVersionString])
    } else if mode == "reset-counter" {
        let prefix = try ScriptWidgetStorageNamespaces.registerFresh(name: "Counter", container: root, defaults: backend).namespace
        guard ScriptWidgetAtomicPreferences.mutate(container: root, defaults: backend, namespace: prefix, operation: { staged in
            try staged.writeValue("0", forKey: prefix + "count"); try staged.writeValue("0", forKey: prefix + "mirror"); return true
        }) else { fail("reset-failed") }
    } else if mode == "increment" {
        let prefix = try namespace("Counter")
        let observed = ObservedProbeBackend(backend)
        let deadline = DispatchTime.now().uptimeNanoseconds + 20_000_000_000
        var rejections = 0
        for index in 0..<expected {
            while true {
                observed.enteredLock = false
                var operationStarted = false
                let saved = ScriptWidgetAtomicPreferences.mutate(container: root, defaults: observed, namespace: prefix, operation: { staged in
                    operationStarted = true
                    guard let value = try staged.readValue(forKey: prefix + "count") as? String, let count = Int(value),
                          try staged.readValue(forKey: prefix + "mirror") as? String == value else { throw ScriptWidgetStorageFileError.invalidData }
                    let next = String(count + 1)
                    try staged.writeValue(next, forKey: prefix + "count"); try staged.writeValue(next, forKey: prefix + "mirror")
                    return true
                })
                if saved { break }
                // Once synchronize was called inside the lock, a failure is
                // data/transaction-related and must never be retried away.
                guard !observed.enteredLock else { fail("transaction-failed", committed: index, lockRejections: rejections, operationStarted: operationStarted) }
                rejections += 1
                try Data().write(to: root.appendingPathComponent("contention-observed"), options: .atomic)
                guard DispatchTime.now().uptimeNanoseconds < deadline else {
                    fail("lock-unavailable-deadline", committed: index, lockRejections: rejections)
                }
                usleep(2_000 + UInt32(getpid() % 7) * 1_000)
            }
        }
        try emit(["mode": mode, "passed": true, "committed": expected, "lockRejections": rejections])
    } else if mode == "expect-lock-rejection" {
        let prefix = try namespace("Counter"), observed = ObservedProbeBackend(backend)
        let start = DispatchTime.now().uptimeNanoseconds
        let saved = ScriptWidgetAtomicPreferences.mutate(container: root, defaults: observed, namespace: prefix) { _ in false }
        guard !saved, !observed.enteredLock else { fail("expected-lock-rejection-not-observed") }
        try emit(["mode": mode, "passed": true, "mutationStarted": false,
                  "elapsedMilliseconds": Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000])
    } else if mode == "hold-counter-lock" {
        guard (1...10_000).contains(expected) else { exit(2) }
        let prefix = try namespace("Counter")
        guard ScriptWidgetStorageLock.withExclusiveAccess(container: root, namespace: prefix, operation: {
            guard (try? Data().write(to: root.appendingPathComponent("counter-lock-held"), options: .atomic)) != nil else { return false }
            let end = DispatchTime.now().uptimeNanoseconds + UInt64(expected) * 1_000_000
            while !FileManager.default.fileExists(atPath: root.appendingPathComponent("release-counter-lock").path),
                  DispatchTime.now().uptimeNanoseconds < end { usleep(1_000) }
            return true
        }) == true else { fail("holder-lock-not-acquired") }
        try emit(["mode": mode, "passed": true])
    } else if mode == "break-counter-mirror" {
        let prefix = try namespace("Counter")
        guard ScriptWidgetAtomicPreferences.mutate(container: root, defaults: backend, namespace: prefix, operation: { staged in
            try staged.writeValue("0", forKey: prefix + "count")
            try staged.writeValue("1", forKey: prefix + "mirror")
            return true
        }) else { fail("corrupt-fixture-setup-failed") }
    } else if mode == "read-broken-counter" {
        let prefix = try namespace("Counter")
        guard try backend.readValue(forKey: prefix + "count") as? String == "0",
              try backend.readValue(forKey: prefix + "mirror") as? String == "1" else { fail("corrupt-fixture-was-changed") }
        try emit(["mode": mode, "passed": true])
    } else if mode == "break-record-file" || mode == "read-broken-record-file" {
        let prefix = try namespace("Counter")
        guard let owner = prefix.split(separator: ":").last, UUID(uuidString: String(owner)) != nil else { fail("invalid-fixture-owner") }
        let file = root.appendingPathComponent(ScriptWidgetStorageFiles.directoryName)
            .appendingPathComponent("records").appendingPathComponent(String(owner) + ".bin")
        let corrupt = Data("probe-corrupt-record".utf8)
        if mode == "break-record-file" { try corrupt.write(to: file, options: .atomic) }
        else {
            guard try Data(contentsOf: file) == corrupt else { fail("corrupt-file-was-changed") }
            try emit(["mode": mode, "passed": true])
        }
    } else if mode == "crash-before" || mode == "crash-after" {
        let prefix = try namespace("Counter")
        guard ScriptWidgetAtomicPreferences.mutate(container: root, defaults: backend, namespace: prefix, operation: { staged in
            try staged.writeValue(String(expected), forKey: prefix + "count"); try staged.writeValue(String(expected), forKey: prefix + "mirror")
            if mode == "crash-before" { _exit(86) }
            return true
        }) else { fail("crash-stage-failed") }
        _exit(86)
    } else if mode == "read-counter" {
        let prefix = try namespace("Counter")
        guard try backend.readValue(forKey: prefix + "count") as? String == String(expected),
              try backend.readValue(forKey: prefix + "mirror") as? String == String(expected) else { fail("counter-mismatch") }
        try emit(["mode": mode, "passed": true, "counter": expected, "mirrorMatches": true])
    } else { exit(2) }
} catch {
    // Never print records or native paths in diagnostics.
    fputs("Storage file probe failed: \(type(of: error))\n", stderr)
    exit(1)
}
