import Foundation
import CryptoKit
import Darwin

/// Throwing native storage access keeps corrupt/unavailable files distinct from
/// absent values. Legacy defaults remain an adapter for compatibility/migration.
protocol ScriptWidgetStorageBackend: AnyObject {
    func readValue(forKey key: String) throws -> Any?
    func writeValue(_ value: Any, forKey key: String) throws
    func removeValue(forKey key: String) throws
    func legacyValues() throws -> [String: Any]
    func values(in namespace: String) throws -> [(String, Any)]
    /// Caller holds the namespace lock. File backends commit all changed keys
    /// together only when the callback succeeds and returns true.
    func mutateValues(in namespace: String, operation: (any ScriptWidgetStorageBackend) throws -> Bool) throws -> Bool
    func synchronize() -> Bool
}

extension UserDefaults: ScriptWidgetStorageBackend {
    func readValue(forKey key: String) -> Any? { object(forKey: key) }
    func writeValue(_ value: Any, forKey key: String) { set(value, forKey: key) }
    func removeValue(forKey key: String) { removeObject(forKey: key) }
    func legacyValues() -> [String: Any] { dictionaryRepresentation() }
    func values(in namespace: String) -> [(String, Any)] {
        dictionaryRepresentation().compactMap { $0.key.utf8.starts(with: namespace.utf8) ? ($0.key, $0.value) : nil }
    }
    func mutateValues(in namespace: String, operation: (any ScriptWidgetStorageBackend) throws -> Bool) throws -> Bool { try operation(self) }
}

/// Cross-process, package-scoped coordination. The application-group root is
/// supplied by the OS; children are opened relative to directory descriptors.
/// No JavaScript is evaluated while holding the lock.
enum ScriptWidgetStorageLock {
    static let timeoutNanoseconds: UInt64 = 200_000_000

    static func withExclusiveAccess<T>(container: URL, namespace: String, operation: () -> T) -> T? {
        let root = container.standardizedFileURL.resolvingSymlinksInPath()
        let rootFD = open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard rootFD >= 0 else { return nil }
        defer { close(rootFD) }
        let directory = "__StorageLocks.v1"
        guard mkdirat(rootFD, directory, 0o700) == 0 || errno == EEXIST else { return nil }
        let directoryFD = openat(rootFD, directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { return nil }
        defer { close(directoryFD) }
        let name = SHA256.hash(data: Data(namespace.utf8)).map { String(format: "%02x", $0) }.joined() + ".lock"
        let fd = openat(directoryFD, name, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var attributes = stat()
        guard fstat(fd, &attributes) == 0, attributes.st_mode & S_IFMT == S_IFREG, attributes.st_nlink == 1 else { return nil }
        let start = DispatchTime.now().uptimeNanoseconds
        while flock(fd, LOCK_EX | LOCK_NB) != 0 {
            guard errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR,
                  DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds else { return nil }
            usleep(1_000)
        }
        defer { _ = flock(fd, LOCK_UN) }
        return operation()
    }
}

/// Synchronize and compare under the shared lock. The file backend stages a
/// whole namespace and commits once; legacy preferences retain their existing
/// persistence semantics until the native migration is activated.
enum ScriptWidgetAtomicPreferences {
    static let maximumKeyBytes = 256
    static let maximumValueBytes = 256 * 1_024

    static func mutate(container: URL?, defaults: any ScriptWidgetStorageBackend, namespace: String, isActive: () -> Bool = { true }, operation: (any ScriptWidgetStorageBackend) throws -> Bool) -> Bool {
        func perform() -> Bool {
            guard isActive(), defaults.synchronize(), isActive() else { return false }
            guard (try? defaults.mutateValues(in: namespace, operation: operation)) == true else { return false }
            _ = defaults.synchronize()
            return true
        }
        if let container { return ScriptWidgetStorageLock.withExclusiveAccess(container: container, namespace: namespace, operation: perform) ?? false }
        guard defaults is ScriptWidgetPreviewStorageBackend else { return false }
        return perform()
    }

    static func compareAndSetString(container: URL?, defaults: any ScriptWidgetStorageBackend, namespace: String, key: String, expected: String, value: String, isActive: () -> Bool = { true }, canStore: (any ScriptWidgetStorageBackend, Any) -> Bool = { _, _ in true }) -> Bool {
        guard !key.isEmpty, key.utf8.count <= maximumKeyBytes,
              expected.utf8.count <= maximumValueBytes, value.utf8.count <= maximumValueBytes else { return false }
        return mutate(container: container, defaults: defaults, namespace: namespace, isActive: isActive) { store in
            let name = namespace + key
            let existing = try store.readValue(forKey: name)
            guard existing == nil || existing is String,
                  (existing as? String ?? "") == expected, canStore(store, value) else { return false }
            try store.writeValue(value, forKey: name)
            return true
        }
    }

    static func encodeJSON(_ value: [AnyHashable: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]),
              data.count <= maximumValueBytes else { return nil }
        return data
    }

    static func compareAndSetJSON(container: URL?, defaults: any ScriptWidgetStorageBackend, namespace: String, key: String, expected: [AnyHashable: Any], value: [AnyHashable: Any], isActive: () -> Bool = { true }, canStore: (any ScriptWidgetStorageBackend, Any) -> Bool = { _, _ in true }) -> Bool {
        guard !key.isEmpty, key.utf8.count <= maximumKeyBytes,
              let expectedData = encodeJSON(expected), let newData = encodeJSON(value) else { return false }
        return mutate(container: container, defaults: defaults, namespace: namespace, isActive: isActive) { store in
            let name = namespace + key
            if let existing = try store.readValue(forKey: name) {
                guard let data = existing as? Data, data.count <= maximumValueBytes,
                      let object = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any],
                      encodeJSON(object) == expectedData else { return false }
            } else if !expected.isEmpty { return false }
            guard canStore(store, newData) else { return false }
            try store.writeValue(newData, forKey: name)
            return true
        }
    }
}

/// One read-only preview owns one transient namespace. It never reads a
/// preference domain or creates an App Group lock/file. Byte keys preserve
/// Unicode distinctions; a failed transaction restores its whole prior state.
final class ScriptWidgetPreviewStorageBackend: ScriptWidgetStorageBackend {
    private let namespace: Data
    private let lock = NSRecursiveLock()
    private var entries: [Data: (String, Any)] = [:]
    private var staging = false

    init(namespace: String) { self.namespace = Data(namespace.utf8) }
    private func checked(_ key: String) throws -> Data {
        let data = Data(key.utf8)
        guard data.starts(with: namespace), (1...ScriptWidgetAtomicPreferences.maximumKeyBytes).contains(data.count - namespace.count) else {
            throw ScriptWidgetStorageNamespaceError.invalidName
        }
        return data
    }
    private func validate() throws {
        guard entries.count <= ScriptWidgetStorageNamespaces.maximumNamespaceKeys else { throw ScriptWidgetStorageNamespaceError.limitExceeded }
        let bytes = try entries.values.reduce(0) { total, entry in
            let count: Int
            if let text = entry.1 as? String { count = text.utf8.count }
            else if let data = entry.1 as? Data { count = data.count }
            else { throw ScriptWidgetStorageNamespaceError.invalidRegistry }
            guard count <= ScriptWidgetAtomicPreferences.maximumValueBytes else { throw ScriptWidgetStorageNamespaceError.limitExceeded }
            return total + count
        }
        guard bytes <= ScriptWidgetStorageNamespaces.maximumNamespaceBytes else { throw ScriptWidgetStorageNamespaceError.limitExceeded }
    }
    func readValue(forKey key: String) throws -> Any? {
        lock.lock(); defer { lock.unlock() }
        return entries[try checked(key)]?.1
    }
    func writeValue(_ value: Any, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try checked(key), previous = entries
        entries[data] = (key, value)
        if !staging {
            do { try validate() } catch { entries = previous; throw error }
        }
    }
    func removeValue(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        entries.removeValue(forKey: try checked(key))
    }
    func values(in namespace: String) throws -> [(String, Any)] {
        lock.lock(); defer { lock.unlock() }
        guard Data(namespace.utf8) == self.namespace else { throw ScriptWidgetStorageNamespaceError.invalidName }
        return entries.keys.sorted { $0.lexicographicallyPrecedes($1) }.map { entries[$0]! }
    }
    func legacyValues() throws -> [String: Any] { throw ScriptWidgetStorageNamespaceError.invalidRegistry }
    func synchronize() -> Bool { true }
    func mutateValues(in namespace: String, operation: (any ScriptWidgetStorageBackend) throws -> Bool) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !staging, Data(namespace.utf8) == self.namespace else { throw ScriptWidgetStorageNamespaceError.invalidName }
        let previous = entries
        staging = true; defer { staging = false }
        do {
            guard try operation(self) else { entries = previous; return false }
            try validate(); return true
        } catch { entries = previous; throw error }
    }
}
