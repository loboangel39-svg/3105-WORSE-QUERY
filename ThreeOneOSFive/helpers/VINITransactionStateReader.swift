import Foundation

enum VINITransactionState: Equatable {
    case prepared, applied, restorePending, restored, failed, unknown
}

/// Read-only bridge over the existing transaction and backup APIs. It never
/// writes journals/manifests, resolves a target by filename, or invokes apply/
/// restore. The remote target association is deliberately strict.
struct VINITransactionStateReader {
    private let backupStore: VINIDualBackupStore

    init(backupStore: VINIDualBackupStore) { self.backupStore = backupStore }

    static func live() throws -> VINITransactionStateReader {
        VINITransactionStateReader(backupStore: try VINIDualBackupStore.live())
    }

    func state(targetID: String, projectID: UUID, packageDigest: Data) -> VINITransactionState {
        guard let records = try? backupStore.allRecords() else { return .unknown }
        let matches = records.filter { $0.projectID == projectID && $0.packageDigest == packageDigest }
        guard matches.count == 1, let record = matches.first else { return .unknown }
        // VINIDualBackupStore currently persists only its local package.<projectID>
        // identity. Without an exact remote target binding, never attribute it.
        guard record.targetID == targetID else { return .unknown }
        guard let transactionID = record.transactionID,
              let receipt = try? backupStore.receipt(record), receipt.id == transactionID,
              let snapshot = try? PatchTransaction.journalSnapshot(receipt: receipt) else { return .unknown }

        switch record.phase {
        case .applied:
            guard record.lastVerifiedEnabled, snapshot.status == "applied",
                  (try? backupStore.verifiedManifest(record, role: "A", stage: "committed")) != nil,
                  (try? backupStore.verifiedManifest(record, role: "B", stage: "committed")) != nil else { return .unknown }
            return .applied
        case .restoreStaging, .restoring, .recoveryRequired:
            return .restorePending
        case .restored:
            return snapshot.status == "restored" || snapshot.status == "rolledBack" ? .restored : .unknown
        case .prepared:
            return snapshot.status == "prepared" ? .prepared : .unknown
        case .preparing:
            return .failed
        }
    }
}
