import Foundation
import CryptoKit

// One build-pinned staging assignment. It is deliberately NOT any dashboard card.
// Only the transaction engine's caller-owned resolver is used, never DevicePatchService.
actor VINIIsolatedFixture {
    static let projectID = UUID(uuidString: "E4F7CF4A-D0D9-4150-93DE-17AACCD5F037")!
    static let targetID = "package." + projectID.uuidString
    static let bundleID = "com.example.vini.acceptance"
    static let original = Data("VINI 2F owned original fixture\n".utf8)
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VINI2FOwnedFixture", isDirectory: true)
    }
    private var container: URL { directory.appendingPathComponent("Container", isDirectory: true) }
    private var destination: URL { container.appendingPathComponent("Documents/acceptance.bin") }
    private var store: VINIDualBackupStore {
        VINIDualBackupStore(root: directory.appendingPathComponent("DualBackups"), engineRoot: directory.appendingPathComponent("EngineBackups"))
    }
    private func digest(_ bytes: Data) -> Data { Data(SHA256.hash(data: bytes)) }
    private func hash(_ bytes: Data) -> String { digest(bytes).map { String(format: "%02x", $0) }.joined() }
    private func roots() throws -> [String: URL] {
        if FileManager.default.fileExists(atPath: directory.path) {
            let properties = try directory.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard properties.isSymbolicLink != true else { throw VINIPatchFailure.invalidScope }
        }
        return [Self.bundleID: container]
    }
    func inspection() throws -> (String, Bool, Bool, URL?) {
        guard let record = try store.loadRecord(Self.projectID) else { return ("Sin ensayo aplicado", true, false, nil) }
        try store.validateRoots(record, try roots())
        let receipt = try store.receipt(record)
        if record.phase == .restored {
            let valid = try PatchTransaction.verifyState(receipt: receipt, original: true, containerResolver: resolver)
            return (valid ? "Restore verificado" : "Archivo propio cambiado después del Restore", valid, false,
                    directory.appendingPathComponent("restore-evidence.json"))
        }
        if record.phase == .applied {
            let valid = try PatchTransaction.verifyState(receipt: receipt, original: false, containerResolver: resolver)
            return (valid ? "Apply verificado" : "Cambios posteriores; Restore preservará su copia", false, true,
                    directory.appendingPathComponent("apply-evidence.json"))
        }
        return ("Recuperación requerida; journal conservado", false, true, nil)
    }
    private func resolver(_ id: String) throws -> URL {
        guard id == Self.bundleID else { throw VINIPatchFailure.invalidScope }
        _ = try roots()
        return container
    }
    private func project(_ bytes: Data) throws -> PatchProject {
        guard hash(bytes) == VINIStagingEnvironment.fixtureSHA256 else { throw VINIPatchFailure.invalidManifest }
        let value = try PatchPackageCodec.decode(bytes, password: nil).project
        guard value.id == Self.projectID, value.rules.count == 1, value.directories.isEmpty,
              value.allBundleIdentifiers == [Self.bundleID],
              value.rules[0].relativePath == "Documents/acceptance.bin" else { throw VINIPatchFailure.invalidScope }
        return value
    }
    func apply(bytes: Data, injectFailure: Bool = false) throws -> String {
        let project = try project(bytes)
        let fm = FileManager.default
        if let record = try store.loadRecord(Self.projectID), ![.restored].contains(record.phase) {
            throw VINIPatchFailure.recoveryRequired
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = try VINIRootIdentity.read(directory)
        for folder in [container, container.appendingPathComponent("Documents")] {
            if !fm.fileExists(atPath: folder.path) { try fm.createDirectory(at: folder, withIntermediateDirectories: false) }
            _ = try VINIRootIdentity.read(folder)
        }
        _ = try roots()
        if fm.fileExists(atPath: destination.path) {
            let type = try destination.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard type.isRegularFile == true, type.isSymbolicLink != true else { throw VINIPatchFailure.invalidScope }
        }
        if !fm.fileExists(atPath: destination.path) { try Self.original.write(to: destination, options: .atomic) }
        guard try Data(contentsOf: destination) == Self.original else { throw VINIPatchFailure.concurrentChange }
        // Isolated package import: exact received bytes + unchanged codec, outside the live library.
        try bytes.write(to: directory.appendingPathComponent("Imported.3105"), options: .atomic)
        guard try self.project(Data(contentsOf: directory.appendingPathComponent("Imported.3105"))).id == project.id else { throw VINIPatchFailure.invalidManifest }
        let rootIdentity = try VINIRootIdentity.read(container)
        var record = VINIOperationRecord(targetID: Self.targetID, projectID: project.id,
            operationID: UUID(), transactionID: nil, previousTransactionID: nil,
            phase: .preparing, lastVerifiedEnabled: false, desiredEnabled: true,
            packageDigest: digest(bytes), plannedRules: project.rules.map { VINIPlannedRule(id: $0.id, bundleID: $0.bundleID, path: $0.relativePath, digest: digest($0.replacementData)) },
            plannedDirectories: [], roots: [Self.bundleID: rootIdentity], startedAt: Date())
        try store.save(record)
        do {
            let receipt = try PatchTransaction.apply(project: project, backupRoot: store.engineRoot,
                containerResolver: resolver,
                beforeWrite: { _ in if injectFailure { throw VINIPatchFailure.concurrentChange } },
                beforeMutation: { receipt in
                    record.transactionID = receipt.id; record.phase = .prepared
                    try self.store.save(record)
                    let snapshot = try PatchTransaction.journalSnapshot(receipt: receipt)
                    guard snapshot.files.first?.originalDigest == self.digest(Self.original) else { throw VINIPatchFailure.concurrentChange }
                    try self.store.preparePair(record)
                    _ = try self.store.verifiedManifest(record, role: "A", stage: "prepared")
                    _ = try self.store.verifiedManifest(record, role: "B", stage: "prepared")
                }, beforeRollback: { _ in
                    try self.store.validateRoots(record, try self.roots())
                })
            record.transactionID = receipt.id
            try store.sealApplied(record)
            guard try PatchTransaction.verifyState(receipt: receipt, original: false, containerResolver: resolver) else { throw VINIPatchFailure.recoveryRequired }
            record.phase = .applied; record.lastVerifiedEnabled = true
            try store.save(record)
            try saveEvidence(record, applied: true)
            return "Apply verificado · fixture propio · receipt " + receipt.id.uuidString
        } catch {
            if let id = record.transactionID {
                let receipt = try store.receipt(record)
                if (try? PatchTransaction.verifyState(receipt: receipt, original: true, containerResolver: resolver)) == true,
                   (try? PatchTransaction.journalSnapshot(receipt: receipt).status) == "rolledBack" {
                    record.phase = .restored; record.lastVerifiedEnabled = false; record.desiredEnabled = false
                    try store.sealRestored(record)
                    try saveEvidence(record, applied: false)
                    _ = id
                } else { record.phase = .recoveryRequired }
            } else { record.phase = .recoveryRequired }
            try store.save(record)
            throw error
        }
    }
    func restore() throws -> String {
        guard var record = try store.loadRecord(Self.projectID), record.phase == .applied || record.phase == .restoring || record.phase == .recoveryRequired else { throw VINIPatchFailure.recoveryRequired }
        try store.validateRoots(record, try roots())
        // Verify both independent original copies before attempting any restore.
        do { _ = try store.verifiedManifest(record, role: "A", stage: "committed") }
        catch { let b = try store.bestB(record); try store.repairPrimary(record, from: b) }
        _ = try store.bestB(record)
        let receipt = try store.receipt(record)
        record.phase = .restoring; record.operationID = UUID(); record.desiredEnabled = false
        try store.save(record)
        do {
            try PatchTransaction.restore(receipt: receipt, allowChangedTargets: true, containerResolver: resolver,
                preserveCurrentState: { snapshots in
                    _ = try self.store.preserve(record, snapshots: snapshots, force: true)
                    for snapshot in snapshots { try self.store.verifyLive(snapshot, roots: try self.roots()) }
                })
            guard try PatchTransaction.verifyState(receipt: receipt, original: true, containerResolver: resolver),
                  try Data(contentsOf: destination) == Self.original else { throw VINIPatchFailure.recoveryRequired }
            try store.sealRestored(record)
            record.phase = .restored; record.lastVerifiedEnabled = false; try store.save(record)
            try saveEvidence(record, applied: false)
            return "Restore verificado · hash original recuperado"
        } catch { record.phase = .recoveryRequired; try store.save(record); throw error }
    }
    private func saveEvidence(_ record: VINIOperationRecord, applied: Bool) throws {
        let receipt = try store.receipt(record)
        let journal = try PatchTransaction.journalSnapshot(receipt: receipt)
        let values = ["targetID": Self.targetID, "remotePatchID": VINIStagingEnvironment.fixtureID,
            "packageID": Self.projectID.uuidString, "projectID": record.projectID.uuidString,
            "transactionReceipt": receipt.id.uuidString, "phase": record.phase.rawValue,
            "journal": journal.status, "originalSHA256": hash(Self.original),
            "currentSHA256": hash(try Data(contentsOf: destination)),
            "expectedAppliedSHA256": journal.files[0].replacementDigest.map { String(format: "%02x", $0) }.joined(),
            "state": applied ? "applied_verified" : "restored_verified"]
        try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent(applied ? "apply-evidence.json" : "restore-evidence.json"), options: .atomic)
    }
}
