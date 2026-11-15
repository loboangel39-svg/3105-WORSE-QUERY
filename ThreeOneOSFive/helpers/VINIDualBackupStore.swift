import CryptoKit
import Darwin
import Foundation

enum VINIPatchFailure: Error {
    case invalidManifest, invalidBackup, invalidScope, invalidContainer, concurrentChange
    case storageUnavailable, retentionLimit, missingPackage, lockedPackage, conflictingTarget, recoveryRequired
}
enum VINIOperationPhase: String, Codable {
    case preparing, prepared, applied, restoreStaging, restoring, restored, recoveryRequired
}
struct VINIRootIdentity: Codable, Equatable {
    let path: String
    let device: UInt64
    let inode: UInt64
    static func read(_ url: URL) throws -> VINIRootIdentity {
        let path = PatchPathValidator.canonicalFileURL(url).path
        let fd = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw VINIPatchFailure.invalidContainer }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw VINIPatchFailure.invalidContainer }
        return VINIRootIdentity(path: path, device: UInt64(bitPattern: Int64(info.st_dev)), inode: UInt64(info.st_ino))
    }
}
struct VINIPlannedRule: Codable, Equatable {
    let id: UUID
    let bundleID: String
    let path: String
    let digest: Data
}
struct VINIOperationRecord: Codable {
    let targetID: String
    let projectID: UUID
    var operationID: UUID
    var transactionID: UUID?
    var previousTransactionID: UUID?
    var phase: VINIOperationPhase
    var lastVerifiedEnabled: Bool
    var desiredEnabled: Bool
    let packageDigest: Data
    let plannedRules: [VINIPlannedRule]
    let plannedDirectories: [String]
    var roots: [String: VINIRootIdentity]
    let startedAt: Date
}
struct VINIBackupManifest: Codable {
    let schema: Int
    let role: String
    let stage: String
    let targetID: String
    let projectID: UUID
    let transactionID: UUID
    let journalName: String
    let journalDigest: Data
    let status: String
    let files: [PatchJournalFile]
    let directories: [PatchJournalDirectory]
    let roots: [String: VINIRootIdentity]
    let copiedDigests: [String: Data]
}
struct VINIRecoveryFile: Codable, Equatable {
    let bundleID: String
    let relativePath: String
    let existed: Bool
    let filename: String?
    let digest: Data?
}
struct VINIRecoveryManifest: Codable {
    let schema: Int
    let recoveryID: UUID
    let targetID: String
    let projectID: UUID
    let transactionID: UUID
    let operationID: UUID
    let createdAt: Date
    let roots: [String: VINIRootIdentity]
    let files: [VINIRecoveryFile]
}

// Owns copies and metadata only. Target writes stay in PatchTransaction.
struct VINIDualBackupStore {
    let root: URL
    let engineRoot: URL
    var maximumRecoveryBytes: UInt64 = 512 * 1024 * 1024
    var maximumStoreBytes: UInt64 = 2 * 1024 * 1024 * 1024
    var maximumRecoveryGenerations = 8
    private var fm: FileManager { .default }
    private struct Envelope<T: Codable>: Codable { let payload: Data; let digest: Data }

    static func live() throws -> VINIDualBackupStore {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let root = PatchPathValidator.canonicalFileURL(support.appendingPathComponent("VINISilentPatches", isDirectory: true))
        let engine = PatchPathValidator.canonicalFileURL(try PatchProjectLibrary.backupRootURL())
        let store = VINIDualBackupStore(root: root, engineRoot: engine)
        try store.ensureDirectory(root)
        return store
    }
    func receipt(_ record: VINIOperationRecord) throws -> PatchTransactionReceipt {
        guard let id = record.transactionID else { throw VINIPatchFailure.recoveryRequired }
        return PatchTransactionReceipt(id: id, projectID: record.projectID,
            journalURL: engineRoot.appendingPathComponent(record.projectID.uuidString)
                .appendingPathComponent(id.uuidString).appendingPathComponent("journal.plist"))
    }
    func transactionRoot(_ record: VINIOperationRecord) throws -> URL {
        guard let id = record.transactionID else { throw VINIPatchFailure.recoveryRequired }
        return root.appendingPathComponent("Transactions").appendingPathComponent(record.projectID.uuidString)
            .appendingPathComponent(id.uuidString)
    }
    private func indexURL(_ id: UUID) -> URL { root.appendingPathComponent("Targets").appendingPathComponent(id.uuidString + ".json") }
    func loadRecord(_ id: UUID) throws -> VINIOperationRecord? {
        let url = indexURL(id)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let record: VINIOperationRecord = try readEnvelope(url)
        guard record.projectID == id, record.targetID == "package." + id.uuidString else { throw VINIPatchFailure.invalidManifest }
        return record
    }
    func save(_ record: VINIOperationRecord) throws {
        guard record.targetID == "package." + record.projectID.uuidString else { throw VINIPatchFailure.invalidManifest }
        try writeEnvelope(record, to: indexURL(record.projectID), replacing: true)
        if record.transactionID != nil {
            try writeEnvelope(record, to: try transactionRoot(record).appendingPathComponent("state.json"), replacing: true)
        }
    }
    func allRecords() throws -> [VINIOperationRecord] {
        let directory = root.appendingPathComponent("Targets")
        guard fm.fileExists(atPath: directory.path) else { return [] }
        try assertSafe(directory, below: root)
        return try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map { url in
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent), url.pathExtension == "json",
                  let record = try loadRecord(id) else { throw VINIPatchFailure.invalidManifest }
            return record
        }
    }
    func validateRoots(_ record: VINIOperationRecord, _ roots: [String: URL]) throws {
        guard !record.roots.isEmpty, Set(record.roots.keys) == Set(roots.keys) else { throw VINIPatchFailure.invalidContainer }
        for (id, root) in roots {
            guard try VINIRootIdentity.read(root) == record.roots[id] else { throw VINIPatchFailure.invalidContainer }
        }
    }
    func validateScope(_ record: VINIOperationRecord, _ snapshot: PatchJournalSnapshot) throws {
        guard snapshot.receipt.projectID == record.projectID,
              record.transactionID == snapshot.receipt.id,
              snapshot.files.count == record.plannedRules.count else { throw VINIPatchFailure.invalidScope }
        let planned = Dictionary(uniqueKeysWithValues: record.plannedRules.map { ($0.id, $0) })
        guard planned.count == snapshot.files.count else { throw VINIPatchFailure.invalidScope }
        for file in snapshot.files {
            guard let expected = planned[file.ruleID], expected.bundleID == file.bundleID,
                  expected.path == file.relativePath, expected.digest == file.replacementDigest,
                  try PatchPathValidator.canonicalRelativePath(file.relativePath) == file.relativePath,
                  file.containerFingerprint.count == 32 else { throw VINIPatchFailure.invalidScope }
            if file.originalExisted {
                guard file.backupFilename == file.ruleID.uuidString + ".original",
                      file.originalDigest?.count == 32 else { throw VINIPatchFailure.invalidBackup }
            } else if file.backupFilename != nil || file.originalDigest != nil { throw VINIPatchFailure.invalidBackup }
            if let name = file.appliedFilename, name != file.ruleID.uuidString + ".applied" { throw VINIPatchFailure.invalidBackup }
        }
        let allowed = Set(record.plannedDirectories)
        for directory in snapshot.directories {
            guard allowed.contains(directory.bundleID + "\0" + directory.relativePath) else { throw VINIPatchFailure.invalidScope }
        }
    }
    func preparePair(_ record: VINIOperationRecord) throws {
        let primary = try receipt(record)
        let snapshot = try PatchTransaction.journalSnapshot(receipt: primary)
        try validateScope(record, snapshot)
        guard snapshot.status == "prepared", !record.roots.isEmpty else { throw VINIPatchFailure.invalidManifest }
        let destination = try transactionRoot(record)
        try ensureDirectory(destination)
        let files = try fileDigests(snapshot, directory: primary.journalURL.deletingLastPathComponent())
        try requireSpace(bytes: files.keys.reduce(0) { $0 + fileSize(primary.journalURL.deletingLastPathComponent().appendingPathComponent($1)) })
        let a = manifest(record, snapshot, role: "A", stage: "prepared", journalName: "journal.plist", digests: files, journalDigest: try hash(primary.journalURL))
        try writeEnvelope(a, to: destination.appendingPathComponent("A-prepared.json"), replacing: false)
        let b = destination.appendingPathComponent("B")
        if !fm.fileExists(atPath: b.path) {
            let staging = destination.appendingPathComponent(".B-staging-" + UUID().uuidString)
            try ensureDirectory(staging)
            for name in files.keys.sorted() {
                try copyIndependent(primary.journalURL.deletingLastPathComponent().appendingPathComponent(name), to: staging.appendingPathComponent(name))
            }
            try copyIndependent(primary.journalURL, to: staging.appendingPathComponent("journal.plist"))
            let bm = manifest(record, snapshot, role: "B", stage: "prepared", journalName: "journal.plist", digests: a.copiedDigests, journalDigest: a.journalDigest)
            try writeEnvelope(bm, to: staging.appendingPathComponent("prepared.json"), replacing: false)
            try verifyManifest(record, bm, directory: staging)
            try fm.moveItem(at: staging, to: b)
            try syncDirectory(destination)
        }
        _ = try verifiedManifest(record, role: "A", stage: "prepared")
        _ = try verifiedManifest(record, role: "B", stage: "prepared")
    }
    func sealApplied(_ record: VINIOperationRecord) throws {
        let primary = try receipt(record)
        let snapshot = try PatchTransaction.journalSnapshot(receipt: primary)
        try validateScope(record, snapshot)
        guard snapshot.status == "applied" else { throw VINIPatchFailure.invalidManifest }
        let tx = try transactionRoot(record), b = tx.appendingPathComponent("B")
        let preparedB = try verifiedManifest(record, role: "B", stage: "prepared")
        guard preparedB.files == snapshot.files, preparedB.directories == snapshot.directories else { throw VINIPatchFailure.invalidManifest }
        guard try fileDigests(snapshot, directory: primary.journalURL.deletingLastPathComponent()) == preparedB.copiedDigests else { throw VINIPatchFailure.invalidBackup }
        let digest = try hash(primary.journalURL)
        let a = manifest(record, snapshot, role: "A", stage: "committed", journalName: "journal.plist", digests: preparedB.copiedDigests, journalDigest: digest)
        try writeEnvelope(a, to: tx.appendingPathComponent("A-committed.json"), replacing: false)
        let committed = b.appendingPathComponent("committed-journal.plist")
        if !fm.fileExists(atPath: committed.path) { try copyIndependent(primary.journalURL, to: committed) }
        let bm = manifest(record, snapshot, role: "B", stage: "committed", journalName: "committed-journal.plist", digests: a.copiedDigests, journalDigest: digest)
        try writeEnvelope(bm, to: b.appendingPathComponent("committed.json"), replacing: false)
        _ = try verifiedManifest(record, role: "A", stage: "committed")
        _ = try verifiedManifest(record, role: "B", stage: "committed")
    }
    func sealRestored(_ record: VINIOperationRecord) throws {
        let receipt = try self.receipt(record), snapshot = try PatchTransaction.journalSnapshot(receipt: receipt)
        try validateScope(record, snapshot)
        guard snapshot.status == "restored" || snapshot.status == "rolledBack" else { throw VINIPatchFailure.recoveryRequired }
        let digests = try fileDigests(snapshot, directory: receipt.journalURL.deletingLastPathComponent())
        let a = manifest(record, snapshot, role: "A", stage: "terminal", journalName: "journal.plist", digests: digests, journalDigest: try hash(receipt.journalURL))
        try writeEnvelope(a, to: try transactionRoot(record).appendingPathComponent("A-terminal.json"), replacing: false)
    }
    func verifiedManifest(_ record: VINIOperationRecord, role: String, stage: String) throws -> VINIBackupManifest {
        let tx = try transactionRoot(record)
        let url = role == "A" ? tx.appendingPathComponent("A-" + stage + ".json") : tx.appendingPathComponent("B").appendingPathComponent(stage + ".json")
        let value: VINIBackupManifest = try readEnvelope(url)
        guard value.role == role, value.stage == stage else { throw VINIPatchFailure.invalidManifest }
        let directory = role == "A" ? try receipt(record).journalURL.deletingLastPathComponent() : tx.appendingPathComponent("B")
        try verifyManifest(record, value, directory: directory)
        return value
    }
    func bestB(_ record: VINIOperationRecord) throws -> VINIBackupManifest {
        if let committed = try? verifiedManifest(record, role: "B", stage: "committed") { return committed }
        return try verifiedManifest(record, role: "B", stage: "prepared")
    }
    func repairPrimary(_ record: VINIOperationRecord, from value: VINIBackupManifest) throws {
        guard value.role == "B" else { throw VINIPatchFailure.invalidBackup }
        let tx = try transactionRoot(record), source = tx.appendingPathComponent("B")
        try verifyManifest(record, value, directory: source)
        let primary = try receipt(record).journalURL.deletingLastPathComponent()
        try assertSafe(primary.deletingLastPathComponent(), below: engineRoot)
        let stage = primary.deletingLastPathComponent().appendingPathComponent(".vini-repair-" + UUID().uuidString)
        try ensureDirectory(stage)
        for name in value.copiedDigests.keys.sorted() { try copyIndependent(source.appendingPathComponent(name), to: stage.appendingPathComponent(name)) }
        try copyIndependent(source.appendingPathComponent(value.journalName), to: stage.appendingPathComponent("journal.plist"))
        let a = VINIBackupManifest(schema: 1, role: "A", stage: value.stage, targetID: value.targetID,
            projectID: value.projectID, transactionID: value.transactionID, journalName: "journal.plist",
            journalDigest: value.journalDigest, status: value.status, files: value.files, directories: value.directories,
            roots: value.roots, copiedDigests: value.copiedDigests)
        try verifyManifest(record, a, directory: stage)
        let quarantine = root.appendingPathComponent("Quarantine").appendingPathComponent(record.projectID.uuidString)
            .appendingPathComponent(value.transactionID.uuidString + "-" + UUID().uuidString)
        try ensureDirectory(quarantine.deletingLastPathComponent())
        try writeEnvelope(["transaction": value.transactionID.uuidString, "staging": stage.lastPathComponent,
            "quarantine": quarantine.lastPathComponent], to: tx.appendingPathComponent("repair-plan.json"), replacing: true)
        if fm.fileExists(atPath: primary.path) { try fm.moveItem(at: primary, to: quarantine) }
        try fm.moveItem(at: stage, to: primary)
        try syncDirectory(primary.deletingLastPathComponent())
        try verifyManifest(record, a, directory: primary)
        // Only the owned A manifest is repaired. B and quarantined recovery material stay intact.
        try writeEnvelope(a, to: tx.appendingPathComponent("A-" + value.stage + ".json"), replacing: true)
    }
    func preserve(_ record: VINIOperationRecord, snapshots: [PatchRecoverySnapshot], force: Bool) throws -> UUID? {
        let receipt = try self.receipt(record), journal = try PatchTransaction.journalSnapshot(receipt: receipt)
        try validateScope(record, journal)
        guard snapshots.count == journal.files.count else { throw VINIPatchFailure.invalidScope }
        var files: [VINIRecoveryFile] = [], changed = force
        for (index, pair) in zip(snapshots, journal.files).enumerated() {
            let (snapshot, expected) = pair
            guard snapshot.bundleID == expected.bundleID, snapshot.relativePath == expected.relativePath,
                  snapshot.containerFingerprint == expected.containerFingerprint else { throw VINIPatchFailure.invalidScope }
            if !snapshot.existed || snapshot.digest != expected.replacementDigest { changed = true }
            if snapshot.existed {
                guard let source = snapshot.snapshotURL, let digest = snapshot.digest,
                      source.deletingLastPathComponent().lastPathComponent.hasPrefix(".recovery-"),
                      source.lastPathComponent == "\(index).current" else { throw VINIPatchFailure.invalidScope }
                try assertSafe(source, below: receipt.journalURL.deletingLastPathComponent())
                guard try hash(source) == digest else { throw VINIPatchFailure.invalidBackup }
            } else if snapshot.snapshotURL != nil || snapshot.digest != nil { throw VINIPatchFailure.invalidScope }
            files.append(VINIRecoveryFile(bundleID: snapshot.bundleID, relativePath: snapshot.relativePath,
                existed: snapshot.existed, filename: snapshot.existed ? "\(index).current" : nil, digest: snapshot.digest))
        }
        guard changed else { return nil }
        let parent = root.appendingPathComponent("Recovery").appendingPathComponent(record.projectID.uuidString)
        try ensureDirectory(parent)
        let prior = try completedRecoveries(in: parent)
        for (url, manifest) in prior where manifest.transactionID == receipt.id && manifest.files == files && manifest.roots == record.roots {
            try verifyRecovery(url, manifest)
            return manifest.recoveryID
        }
        guard prior.count < maximumRecoveryGenerations else { throw VINIPatchFailure.retentionLimit }
        let bytes = snapshots.reduce(UInt64(0)) { $0 + ($1.snapshotURL.map(fileSize) ?? 0) }
        guard try treeBytes(root.appendingPathComponent("Recovery")) + bytes <= maximumRecoveryBytes else { throw VINIPatchFailure.retentionLimit }
        try requireSpace(bytes: bytes)
        let id = UUID(), stage = parent.appendingPathComponent(".pending-" + id.uuidString)
        try ensureDirectory(stage)
        for snapshot in snapshots {
            if let source = snapshot.snapshotURL { try copyIndependent(source, to: stage.appendingPathComponent(source.lastPathComponent)) }
        }
        let manifest = VINIRecoveryManifest(schema: 1, recoveryID: id, targetID: record.targetID,
            projectID: record.projectID, transactionID: receipt.id, operationID: record.operationID,
            createdAt: Date(), roots: record.roots, files: files)
        try writeEnvelope(manifest, to: stage.appendingPathComponent("manifest.json"), replacing: false)
        try verifyRecovery(stage, manifest)
        try fm.moveItem(at: stage, to: parent.appendingPathComponent(id.uuidString))
        try syncDirectory(parent)
        return id
    }
    func verifyLive(_ snapshot: PatchRecoverySnapshot, roots: [String: URL]) throws {
        guard let root = roots[snapshot.bundleID] else { throw VINIPatchFailure.invalidContainer }
        let url = try safeTarget(root: root, path: snapshot.relativePath)
        let exists = fm.fileExists(atPath: url.path)
        guard exists == snapshot.existed else { throw VINIPatchFailure.concurrentChange }
        if exists, try hash(url) != snapshot.digest { throw VINIPatchFailure.concurrentChange }
    }
    func currentBytes(_ snapshot: PatchJournalSnapshot, roots: [String: URL]) throws -> UInt64 {
        try snapshot.files.reduce(0) { sum, file in
            guard let root = roots[file.bundleID] else { throw VINIPatchFailure.invalidContainer }
            return sum + fileSize(try safeTarget(root: root, path: file.relativePath))
        }
    }
    func safeTarget(root: URL, path: String) throws -> URL {
        let target = try PatchPathValidator.resolveContainedTargetURL(relativePath: path, containerRoot: root)
        try assertSafe(target, below: root, allowMissing: true)
        return target
    }
    func requireSpace(bytes: UInt64) throws {
        try ensureDirectory(root)
        let free = (try fm.attributesOfFileSystem(forPath: root.path)[.systemFreeSize] as? NSNumber)?.uint64Value
        guard let free, bytes <= UInt64.max - 8 * 1024 * 1024, free > bytes + 8 * 1024 * 1024 else { throw VINIPatchFailure.storageUnavailable }
        guard try treeBytes(root) + bytes <= maximumStoreBytes else { throw VINIPatchFailure.retentionLimit }
    }
    // Retire only owned terminal generations after both new backups have been sealed.
    func rotate(after current: VINIOperationRecord) throws {
        guard current.phase == .applied, current.lastVerifiedEnabled else { throw VINIPatchFailure.invalidManifest }
        _ = try verifiedManifest(current, role: "A", stage: "committed")
        _ = try verifiedManifest(current, role: "B", stage: "committed")
        let parent = root.appendingPathComponent("Transactions").appendingPathComponent(current.projectID.uuidString)
        for directory in try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: directory.lastPathComponent), id != current.transactionID else { continue }
            let old: VINIOperationRecord = try readEnvelope(directory.appendingPathComponent("state.json"))
            guard old.projectID == current.projectID, old.targetID == current.targetID,
                  old.transactionID == id, old.phase == .restored, !old.lastVerifiedEnabled else { continue }
            let receipt = try self.receipt(old)
            guard DevicePatchService.latestReceipt(projectID: old.projectID)?.id != id else { continue }
            _ = try verifiedManifest(old, role: "A", stage: "terminal")
            let snapshot = try PatchTransaction.journalSnapshot(receipt: receipt)
            guard snapshot.status == "restored" || snapshot.status == "rolledBack" else { continue }
            let contents = try fm.contentsOfDirectory(atPath: receipt.journalURL.deletingLastPathComponent().path)
            // An unknown internal recovery copy may be unique. Never discard it to meet a quota.
            guard !contents.contains(where: { $0.hasPrefix(".recovery-") }) else { continue }
            let plan = root.appendingPathComponent("Cleanup").appendingPathComponent(id.uuidString + ".json")
            try writeEnvelope(["owner": current.targetID, "old": id.uuidString,
                "new": current.transactionID!.uuidString], to: plan, replacing: false)
            try assertSafe(receipt.journalURL.deletingLastPathComponent(), below: engineRoot)
            try assertSafe(directory, below: root)
            try fm.removeItem(at: receipt.journalURL.deletingLastPathComponent())
            try fm.removeItem(at: directory)
            try fm.removeItem(at: plan)
        }
    }
    func diagnostic(_ event: String, projectID: UUID?, error: Error? = nil) {
        log("vini.transaction: \(event) project=\(projectID?.uuidString ?? "none") error=\(error.map { String(describing: $0) } ?? "none")")
    }
    private func manifest(_ record: VINIOperationRecord, _ snapshot: PatchJournalSnapshot,
                          role: String, stage: String, journalName: String, digests: [String: Data], journalDigest: Data) -> VINIBackupManifest {
        VINIBackupManifest(schema: 1, role: role, stage: stage, targetID: record.targetID,
            projectID: record.projectID, transactionID: snapshot.receipt.id, journalName: journalName,
            journalDigest: journalDigest, status: snapshot.status, files: snapshot.files,
            directories: snapshot.directories, roots: record.roots, copiedDigests: digests)
    }
    private func verifyManifest(_ record: VINIOperationRecord, _ manifest: VINIBackupManifest, directory: URL) throws {
        guard manifest.schema == 1, manifest.targetID == record.targetID,
              manifest.projectID == record.projectID, manifest.transactionID == record.transactionID,
              manifest.roots == record.roots, !manifest.roots.isEmpty,
              ["journal.plist", "committed-journal.plist"].contains(manifest.journalName) else { throw VINIPatchFailure.invalidManifest }
        let journal = directory.appendingPathComponent(manifest.journalName)
        try assertSafe(journal, below: directory)
        guard try hash(journal) == manifest.journalDigest else { throw VINIPatchFailure.invalidBackup }
        let receipt = PatchTransactionReceipt(id: manifest.transactionID, projectID: manifest.projectID, journalURL: journal)
        let snapshot = try PatchTransaction.journalSnapshot(receipt: receipt)
        try validateScope(record, snapshot)
        guard snapshot.status == manifest.status, snapshot.files == manifest.files,
              snapshot.directories == manifest.directories else { throw VINIPatchFailure.invalidBackup }
        guard try fileDigests(snapshot, directory: directory) == manifest.copiedDigests else { throw VINIPatchFailure.invalidBackup }
    }
    private func fileDigests(_ snapshot: PatchJournalSnapshot, directory: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for file in snapshot.files {
            for (name, expected) in [(file.backupFilename, file.originalDigest), (file.appliedFilename, Optional(file.replacementDigest))] {
                guard let name else { continue }
                guard name == file.ruleID.uuidString + ".original" || name == file.ruleID.uuidString + ".applied",
                      let expected else { throw VINIPatchFailure.invalidBackup }
                let url = directory.appendingPathComponent(name)
                try assertSafe(url, below: directory)
                let actual = try hash(url)
                guard actual == expected else { throw VINIPatchFailure.invalidBackup }
                try syncFile(url)
                result[name] = actual
            }
        }
        return result
    }
    private func completedRecoveries(in parent: URL) throws -> [(URL, VINIRecoveryManifest)] {
        try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil).compactMap { directory in
            guard UUID(uuidString: directory.lastPathComponent) != nil else { return nil }
            let manifest: VINIRecoveryManifest = try readEnvelope(directory.appendingPathComponent("manifest.json"))
            return (directory, manifest)
        }
    }
    private func verifyRecovery(_ directory: URL, _ manifest: VINIRecoveryManifest) throws {
        guard manifest.schema == 1, manifest.targetID == "package." + manifest.projectID.uuidString else { throw VINIPatchFailure.invalidManifest }
        for (index, file) in manifest.files.enumerated() {
            if file.existed {
                guard file.filename == "\(index).current", let digest = file.digest else { throw VINIPatchFailure.invalidBackup }
                let url = directory.appendingPathComponent(file.filename!)
                try assertSafe(url, below: directory)
                guard try hash(url) == digest else { throw VINIPatchFailure.invalidBackup }
            } else if file.filename != nil || file.digest != nil { throw VINIPatchFailure.invalidManifest }
        }
    }
    func hash(_ url: URL) throws -> Data {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw VINIPatchFailure.invalidBackup }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var digest = SHA256()
        while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty { digest.update(data: bytes) }
        return Data(digest.finalize())
    }
    private func copyIndependent(_ source: URL, to destination: URL) throws {
        try ensureDirectory(destination.deletingLastPathComponent())
        let input = open(source.path, O_RDONLY | O_NOFOLLOW)
        guard input >= 0 else { throw VINIPatchFailure.invalidBackup }
        let output = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard output >= 0 else { close(input); throw VINIPatchFailure.invalidBackup }
        let from = FileHandle(fileDescriptor: input, closeOnDealloc: true)
        let to = FileHandle(fileDescriptor: output, closeOnDealloc: true)
        defer { try? from.close(); try? to.close() }
        while let chunk = try from.read(upToCount: 1024 * 1024), !chunk.isEmpty { try to.write(contentsOf: chunk) }
        try to.synchronize()
        let attrs = try fm.attributesOfItem(atPath: source.path)
        var preserved: [FileAttributeKey: Any] = [:]
        for key in [FileAttributeKey.posixPermissions, .protectionKey, .creationDate, .modificationDate] {
            if let value = attrs[key] { preserved[key] = value }
        }
        if !preserved.isEmpty { try fm.setAttributes(preserved, ofItemAtPath: destination.path) }
        guard try hash(source) == hash(destination) else { throw VINIPatchFailure.invalidBackup }
        try to.synchronize()
        try syncDirectory(destination.deletingLastPathComponent())
    }
    private func writeEnvelope<T: Codable>(_ value: T, to url: URL, replacing: Bool) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .millisecondsSince1970
        let payload = try encoder.encode(value), envelope = Envelope<T>(payload: payload, digest: Data(SHA256.hash(data: payload)))
        let bytes = try encoder.encode(envelope)
        if !replacing, fm.fileExists(atPath: url.path) {
            guard try Data(contentsOf: url) == bytes else { throw VINIPatchFailure.invalidManifest }
            return
        }
        let staging = url.deletingLastPathComponent().appendingPathComponent(".write-" + UUID().uuidString)
        let fd = open(staging.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw VINIPatchFailure.storageUnavailable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close(); try? fm.removeItem(at: staging) }
        try handle.write(contentsOf: bytes); try handle.synchronize(); try handle.close()
        if !replacing, fm.fileExists(atPath: url.path) { throw VINIPatchFailure.invalidManifest }
        guard rename(staging.path, url.path) == 0 else { throw VINIPatchFailure.storageUnavailable }
        try syncDirectory(url.deletingLastPathComponent())
    }
    private func readEnvelope<T: Codable>(_ url: URL) throws -> T {
        try assertSafe(url, below: root)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let envelope = try decoder.decode(Envelope<T>.self, from: Data(contentsOf: url))
        guard Data(SHA256.hash(data: envelope.payload)) == envelope.digest else { throw VINIPatchFailure.invalidManifest }
        return try decoder.decode(T.self, from: envelope.payload)
    }
    private func ensureDirectory(_ url: URL) throws {
        let base = url.path == root.path || url.path.hasPrefix(root.path + "/") ? root : engineRoot
        try assertSafe(url, below: base, allowMissing: true)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        try assertSafe(url, below: base)
    }
    private func assertSafe(_ url: URL, below base: URL, allowMissing: Bool = false) throws {
        let path = PatchPathValidator.canonicalFileURL(url).path, root = PatchPathValidator.canonicalFileURL(base).path
        guard path == root || path.hasPrefix(root + "/") else { throw VINIPatchFailure.invalidScope }
        var cursor = URL(fileURLWithPath: root)
        let parts = path == root ? [] : String(path.dropFirst(root.count + 1)).split(separator: "/").map(String.init)
        for part in [""] + parts {
            if !part.isEmpty { cursor.appendPathComponent(part) }
            var info = stat()
            if lstat(cursor.path, &info) != 0 {
                if allowMissing && errno == ENOENT { continue }
                throw VINIPatchFailure.invalidScope
            }
            guard (info.st_mode & mode_t(S_IFMT)) != mode_t(S_IFLNK) else { throw VINIPatchFailure.invalidScope }
        }
    }
    private func syncFile(_ url: URL) throws {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw VINIPatchFailure.invalidBackup }
        defer { close(fd) }
        guard fsync(fd) == 0 else { throw VINIPatchFailure.storageUnavailable }
    }
    private func syncDirectory(_ url: URL) throws {
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw VINIPatchFailure.storageUnavailable }
        defer { close(fd) }
        if fsync(fd) != 0, errno != EINVAL { throw VINIPatchFailure.storageUnavailable }
    }
    private func fileSize(_ url: URL) -> UInt64 {
        ((try? fm.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)?.uint64Value ?? 0
    }
    private func treeBytes(_ directory: URL) throws -> UInt64 {
        guard fm.fileExists(atPath: directory.path) else { return 0 }
        let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
        var result: UInt64 = 0
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw VINIPatchFailure.invalidScope }
            if values.isRegularFile == true { result += UInt64(values.fileSize ?? 0) }
        }
        return result
    }
}
