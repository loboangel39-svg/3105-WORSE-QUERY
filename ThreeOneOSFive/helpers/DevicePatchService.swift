import CryptoKit
import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject,
                      beforeMutation: ((PatchTransactionReceipt, [String: URL]) throws -> Void)? = nil,
                      beforeRollback: ((PatchTransactionReceipt, [String: URL]) throws -> Void)? = nil) throws -> PatchTransactionReceipt {
        mutationLock.lock(); defer { mutationLock.unlock() }
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            let store = try VINIDualBackupStore.live()
            var operation = try makeOperationRecord(project: project, roots: roots)
            try store.save(operation)
            let receipt = try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                },
                beforeMutation: { receipt in
                    operation.transactionID = receipt.id
                    operation.phase = .prepared
                    try store.save(operation)
                    try store.validateRoots(operation, roots)
                    try store.preparePair(operation)
                    try beforeMutation?(receipt, roots)
                },
                beforeRollback: { receipt in
                    try beforeRollback?(receipt, roots)
                    try store.validateRoots(operation, roots)
                }
            )
            operation.transactionID = receipt.id
            try store.sealApplied(operation)
            guard try verifyState(receipt: receipt, original: false) else {
                throw VINIPatchFailure.recoveryRequired
            }
            operation.phase = .applied
            operation.lastVerifiedEnabled = true
            try store.save(operation)
            return receipt
        }
    }

    static func inspectRestore(receipt: PatchTransactionReceipt, validateContainers: (([String: URL]) throws -> Void)? = nil) throws -> PatchRestoreInspection {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try validateContainers?(roots)
            return try PatchTransaction.inspectRestore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func restore(
        receipt: PatchTransactionReceipt,
        allowChangedTargets: Bool = false,
        validateContainers: (([String: URL]) throws -> Void)? = nil,
        preserveCurrentState: (([PatchRecoverySnapshot]) throws -> Void)? = nil,
        beforeWrite: ((Int) throws -> Void)? = nil
    ) throws {
        mutationLock.lock(); defer { mutationLock.unlock() }
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try validateContainers?(roots)
            let store = try VINIDualBackupStore.live()
            guard var operation = try store.loadRecord(receipt.projectID),
                  operation.transactionID == receipt.id else {
                throw VINIPatchFailure.recoveryRequired
            }
            try store.validateRoots(operation, roots)
            do {
                _ = try store.verifiedManifest(operation, role: "A", stage: "committed")
            } catch {
                let backup = try store.bestB(operation)
                try store.repairPrimary(operation, from: backup)
            }
            _ = try store.bestB(operation)
            operation.phase = .restoring
            operation.operationID = UUID()
            operation.desiredEnabled = false
            try store.save(operation)
            try PatchTransaction.restore(
                receipt: receipt,
                // Destination drift is never an authorization for an unsafe overwrite.
                // The parameter remains for source compatibility with the existing UI.
                allowChangedTargets: false,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                },
                beforeWrite: beforeWrite,
                preserveCurrentState: preserveCurrentState
            )
            guard try PatchTransaction.verifyState(receipt: receipt, original: true,
                                                   containerResolver: { id in
                guard let root = roots[id] else { throw PatchPackageError.targetAppUnavailable(id) }
                return root
            }) else { throw VINIPatchFailure.recoveryRequired }
            try store.sealRestored(operation)
            operation.phase = .restored
            operation.lastVerifiedEnabled = false
            try store.save(operation)
        }
    }

    static func resetToAppliedState(
        receipt: PatchTransactionReceipt,
        project: PatchProject
    ) throws {
        mutationLock.lock(); defer { mutationLock.unlock() }
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.resetToAppliedState(
                receipt: receipt,
                fallbackProject: project,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    // VINI_SERVICE_API_BEGIN
    private static let mutationLock = NSRecursiveLock()
    static func withExclusiveMutation<T>(_ body: () throws -> T) rethrows -> T {
        mutationLock.lock(); defer { mutationLock.unlock() }
        return try body()
    }
    static func withExistingContainerAccess<T>(bundleIDs: [String], _ body: ([String: URL]) throws -> T) throws -> T {
        try withResolvedContainers(bundleIDs: bundleIDs, operation: body)
    }
    static func verifyState(receipt: PatchTransactionReceipt, original: Bool,
                            validateContainers: (([String: URL]) throws -> Void)? = nil) throws -> Bool {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try validateContainers?(roots)
            return try PatchTransaction.verifyState(receipt: receipt, original: original,
                containerResolver: { id in
                    guard let root = roots[id] else { throw PatchPackageError.targetAppUnavailable(id) }
                    return root
                })
        }
    }
    static func preserveCurrentState(receipt: PatchTransactionReceipt,
                                     preserve: @escaping ([PatchRecoverySnapshot]) throws -> Void) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.preserveCurrentState(receipt: receipt, containerResolver: { id in
                guard let root = roots[id] else { throw PatchPackageError.targetAppUnavailable(id) }
                return root
            }, preserve: preserve)
        }
    }
    // VINI_SERVICE_API_END

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func makeOperationRecord(project: PatchProject,
                                             roots: [String: URL]) throws -> VINIOperationRecord {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let packageDigest = Data(SHA256.hash(data: try encoder.encode(project)))
        let plannedDirectories = Set(project.directories.map { $0.bundleID + "\0" + $0.relativePath })
        var directories = plannedDirectories
        for rule in project.rules {
            let parts = try PatchPathValidator.canonicalRelativePath(rule.relativePath).split(separator: "/")
            if parts.count > 1 {
                for count in 1..<parts.count {
                    directories.insert(rule.bundleID + "\0" + parts.prefix(count).joined(separator: "/"))
                }
            }
        }
        var identities: [String: VINIRootIdentity] = [:]
        for (bundleID, root) in roots { identities[bundleID] = try VINIRootIdentity.read(root) }
        return VINIOperationRecord(
            targetID: "package." + project.id.uuidString,
            projectID: project.id,
            operationID: UUID(),
            transactionID: nil,
            previousTransactionID: nil,
            phase: .preparing,
            lastVerifiedEnabled: false,
            desiredEnabled: true,
            packageDigest: packageDigest,
            plannedRules: project.rules.map { VINIPlannedRule(id: $0.id, bundleID: $0.bundleID,
                path: $0.relativePath, digest: Data(SHA256.hash(data: $0.replacementData))) },
            plannedDirectories: Array(directories).sorted(),
            roots: identities,
            startedAt: Date()
        )
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]
        var sessions: [ContainerAccessSession] = []

        for bundleID in bundleIDs {
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            do {
                let session = try ContainerAccessCoordinator.acquire(
                    bundleID: bundleID, containerPath: path, operation: .write
                ).get()
                sessions.append(session)
            } catch {
                log("patch: shared container access failed \(bundleID): \(error.localizedDescription)")
                throw PatchPackageError.targetAppUnavailable(bundleID)
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }
        return try withExtendedLifetime(sessions) { try operation(roots) }
    }
}
