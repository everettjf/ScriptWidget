import Foundation
import Darwin

/// Native directory inventory only. Capturing this value never bootstraps an
/// identity index, copies preferences, downloads files or deletes a source.
struct ScriptWidgetLibraryInventory {
    let entries: [String: ScriptWidgetStoragePublicationReceipt]
    let rejectedNames: [String]
    let isComplete: Bool

    static func capture(context: ScriptWidgetPackageStorageContext, isUsingICloud: Bool) throws -> Self {
        try context.validateLibraryRoot()
        guard let names = ScriptWidgetPackageFiles.list(root: context.libraryRoot), names.count <= 8192 else {
            throw ScriptWidgetStorageNamespaceError.unavailable
        }
        var entries: [String: ScriptWidgetStoragePublicationReceipt] = [:], rejected: [String] = []
        for name in names.sorted() {
            if name == "__Build" || name.hasPrefix(ScriptWidgetStorageNamespaces.retiredDirectoryPrefix) || name.hasPrefix(ScriptWidgetStorageNamespaces.replacementPrefix) { continue }
            if name.hasSuffix(".icloud") { rejected.append(name); continue }
            if ScriptWidgetPackageFiles.kind(root: context.libraryRoot, relative: name) == S_IFREG { continue }
            guard ScriptWidgetPackageName.isValid(name) else { rejected.append(name); continue }
            guard let receipt = try? ScriptWidgetPackageFiles.directoryReceipt(root: context.libraryRoot, relative: name) else {
                rejected.append(name); continue
            }
            entries[name] = receipt
        }
        guard entries.count <= ScriptWidgetStorageNamespaces.maximumOwners,
              let after = ScriptWidgetPackageFiles.list(root: context.libraryRoot), Set(after) == Set(names) else {
            throw ScriptWidgetStorageNamespaceError.conflict
        }
        try context.validateLibraryRoot()
        for (name, receipt) in entries {
            guard try ScriptWidgetPackageFiles.directoryReceipt(root: context.libraryRoot, relative: name) == receipt else {
                throw ScriptWidgetStorageNamespaceError.conflict
            }
        }
        return .init(entries: entries, rejectedNames: rejected, isComplete: !isUsingICloud && rejected.isEmpty)
    }
}

struct ScriptWidgetStorageReviewCandidate: Identifiable {
    let owner: ScriptWidgetStorageOwner
    let key: String
    let binding: ScriptWidgetStorageDirectoryBinding?
    let canCopy: Bool
    var id: String { owner.id }
}

struct ScriptWidgetStorageReviewPreview {
    let legacy: ScriptWidgetLegacyStoragePreview
    let candidates: [ScriptWidgetStorageReviewCandidate]
    let text: String
}

/// Only an already-initialized native context can open the review flow. The
/// caller must coordinate writer cutover before bootstrapping; this service
/// never turns a name from a package/backup into an installation identity.
struct ScriptWidgetStorageUpgradeService {
    let context: ScriptWidgetPackageStorageContext
    let isUsingICloud: Bool

    static func live() throws -> Self {
        guard let context = sharedScriptManager.storageContext else { throw ScriptWidgetStorageNamespaceError.inventoryRequired }
        return .init(context: context, isUsingICloud: sharedScriptManager.isUsingiCloud)
    }

    func inventory() throws -> ScriptWidgetLibraryInventory {
        try ScriptWidgetLibraryInventory.capture(context: context, isUsingICloud: isUsingICloud)
    }

    private func state() throws -> (ScriptWidgetStorageNamespaceIndex, [ScriptWidgetStorageDirectoryBinding]) {
        try context.validateLibraryRoot()
        return try ScriptWidgetStorageNamespaces.reviewState(container: context.container, defaults: context.defaults)
    }

    private func visible(_ field: ScriptWidgetLegacyStorageField, bindings: [ScriptWidgetStorageDirectoryBinding]) -> Bool {
        field.candidates.isEmpty || field.candidates.contains { candidate in
            bindings.contains { $0.ownerID == candidate.ownerID && $0.role == .source && $0.location == context.locationIdentifier }
        }
    }

    func fields() throws -> [ScriptWidgetLegacyStorageField] {
        let (index, bindings) = try state()
        return index.legacy.filter { !$0.resolved && visible($0, bindings: bindings) }.sorted { $0.key < $1.key }
    }

    func preview(field: String) throws -> ScriptWidgetStorageReviewPreview {
        let (index, bindings) = try state()
        guard let pending = index.legacy.first(where: { $0.key == field && !$0.resolved }), visible(pending, bindings: bindings) else {
            throw ScriptWidgetStorageNamespaceError.conflict
        }
        let inventory = try inventory()
        let legacy = try ScriptWidgetStorageNamespaces.preview(field: field, container: context.container, defaults: context.defaults)
        let candidates = try pending.candidates.map { candidate -> ScriptWidgetStorageReviewCandidate in
            guard let owner = index.owners.first(where: { $0.id == candidate.ownerID }) else { throw ScriptWidgetStorageNamespaceError.invalidRegistry }
            let binding = bindings.first { $0.ownerID == owner.id && $0.role == .source && $0.location == context.locationIdentifier && $0.name == owner.name }
            let canCopy = owner.active && binding != nil && inventory.entries[owner.name] == binding?.receipt &&
                candidate.key.utf8.count <= ScriptWidgetAtomicPreferences.maximumKeyBytes && legacy.valueBytes <= ScriptWidgetAtomicPreferences.maximumValueBytes
            return .init(owner: owner, key: candidate.key, binding: binding, canCopy: canCopy)
        }
        return .init(legacy: legacy, candidates: candidates,
            text: try ScriptWidgetStorageNamespaces.previewText(legacy, container: context.container, defaults: context.defaults))
    }

    func copy(_ preview: ScriptWidgetStorageReviewPreview, to owners: Set<String>) throws {
        guard !owners.isEmpty, owners.isSubset(of: Set(preview.candidates.filter(\.canCopy).map(\.id))) else {
            throw ScriptWidgetStorageNamespaceError.conflict
        }
        try ScriptWidgetStorageNamespaces.resolve(preview.legacy, to: owners, container: context.container, defaults: context.defaults,
            expectedOwners: preview.candidates.map(\.owner),
            expectedBindings: preview.candidates.filter { owners.contains($0.id) }.compactMap(\.binding), validate: {
                try context.validateLibraryRoot()
                for candidate in preview.candidates where owners.contains(candidate.id) {
                    guard let binding = candidate.binding, binding.location == context.locationIdentifier,
                          binding.ownerID == candidate.id, binding.name == candidate.owner.name,
                          try ScriptWidgetPackageFiles.directoryReceipt(root: context.libraryRoot, relative: binding.name) == binding.receipt else {
                        throw ScriptWidgetStorageNamespaceError.conflict
                    }
                }
            })
    }

    func keepOriginal(_ field: ScriptWidgetLegacyStorageField) throws {
        guard try fields().contains(field) else { throw ScriptWidgetStorageNamespaceError.conflict }
        try ScriptWidgetStorageNamespaces.archiveOriginal(field, container: context.container, defaults: context.defaults,
            validate: { try context.validateLibraryRoot() })
    }
}
