import Foundation
import Darwin

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
                        }) else { exit(3) }
                }
                guard try backend.readValue(forKey: prefixes[ownerIndex] + key) as? String == value else { exit(3) }
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
        }) else { exit(3) }
    } else if mode == "increment" {
        let prefix = try namespace("Counter")
        for _ in 0..<expected {
            guard ScriptWidgetAtomicPreferences.mutate(container: root, defaults: backend, namespace: prefix, operation: { staged in
                guard let value = try staged.readValue(forKey: prefix + "count") as? String, let count = Int(value),
                      try staged.readValue(forKey: prefix + "mirror") as? String == value else { throw ScriptWidgetStorageFileError.invalidData }
                let next = String(count + 1)
                try staged.writeValue(next, forKey: prefix + "count"); try staged.writeValue(next, forKey: prefix + "mirror")
                return true
            }) else { exit(3) }
        }
    } else if mode == "crash-before" || mode == "crash-after" {
        let prefix = try namespace("Counter")
        guard ScriptWidgetAtomicPreferences.mutate(container: root, defaults: backend, namespace: prefix, operation: { staged in
            try staged.writeValue(String(expected), forKey: prefix + "count"); try staged.writeValue(String(expected), forKey: prefix + "mirror")
            if mode == "crash-before" { _exit(86) }
            return true
        }) else { exit(3) }
        _exit(86)
    } else if mode == "read-counter" {
        let prefix = try namespace("Counter")
        guard try backend.readValue(forKey: prefix + "count") as? String == String(expected),
              try backend.readValue(forKey: prefix + "mirror") as? String == String(expected) else { exit(3) }
        try emit(["mode": mode, "passed": true, "counter": expected, "mirrorMatches": true])
    } else { exit(2) }
} catch {
    // Never print records or native paths in diagnostics.
    fputs("Storage file probe failed: \(type(of: error))\n", stderr)
    exit(1)
}
