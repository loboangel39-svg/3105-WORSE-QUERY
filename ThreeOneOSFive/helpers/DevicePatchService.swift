import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject,
                      beforeMutation: ((PatchTransactionReceipt, [String: URL]) throws -> Void)? = nil,
                      beforeRollback: ((PatchTransactionReceipt, [String: URL]) throws -> Void)? = nil) throws -> PatchTransactionReceipt {
        mutationLock.lock(); defer { mutationLock.unlock() }
        let bundleIDs = orderedBundleIdentifiers(in: project)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: project,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                },
                beforeMutation: { receipt in try beforeMutation?(receipt, roots) },
                beforeRollback: { receipt in try beforeRollback?(receipt, roots) }
            )
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
            try PatchTransaction.restore(
                receipt: receipt,
                allowChangedTargets: allowChangedTargets,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                },
                beforeWrite: beforeWrite,
                preserveCurrentState: preserveCurrentState
            )
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
                                     preserve: ([PatchRecoverySnapshot]) throws -> Void) throws {
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
