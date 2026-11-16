import Foundation

enum VINIProductionTargetStatus: Equatable { case loading, prepared, unavailable, revoked, error, applied, restorePending }

struct VINIProductionTargetDescriptor: Equatable {
    let targetID: String
    let remotePatchID: String
    let packageID: UUID
    let projectID: UUID
    let revision: String
    let sha256: String
    let fileSize: Int
    let category: String
    let categoryID: Int?
    let name: String
    let description: String?
    let status: VINIProductionTargetStatus
}

/// Pure data adapter: only a prepared coordinator result that still matches
/// the current authorized catalog can reach the dashboard.
enum VINIProductionTargetModel {
    static func resolve(catalog: [VINIStagingPatch], prepared: [VINIRemotePreparedPackage], stateReader: VINITransactionStateReader? = nil) -> [VINIProductionTargetDescriptor] {
        prepared.compactMap { item in
            guard let patch = catalog.first(where: { $0.id == item.remotePatchID }) else { return nil }
            let targetID: String; let packageID: UUID; let projectID: UUID; let revision: String; let sha256: String; let fileSize: Int; let categoryID: Int?
            if let target = patch.target {
                guard target.availability == "available", ["combat", "visuals", "offsets"].contains(target.category), target.targetID == item.targetID,
                      target.packageID == item.packageID, target.projectID == item.projectID, target.packageRevision == item.revision,
                      target.packageSHA256 == item.sha256, target.fileSize == item.fileSize else { return nil }
                targetID = target.targetID; packageID = target.packageID; projectID = target.projectID; revision = target.packageRevision; sha256 = target.packageSHA256; fileSize = target.fileSize
                categoryID = item.categoryID ?? VINIProductionCategoryRegistry.categoryID(for: target.category)
            } else {
                guard item.categoryID != nil else { return nil }
                targetID = item.targetID; packageID = item.packageID; projectID = item.projectID; revision = item.revision; sha256 = item.sha256; fileSize = item.fileSize; categoryID = item.categoryID
            }
            guard let categoryID, let category = VINIProductionCategoryRegistry.displayName(for: categoryID) else { return nil }
            let state = stateReader?.state(targetID: targetID, projectID: projectID,
                packageDigest: Data(hex: sha256)) ?? .prepared
            return VINIProductionTargetDescriptor(targetID: targetID, remotePatchID: patch.id,
                packageID: packageID, projectID: projectID, revision: revision,
                sha256: sha256, fileSize: fileSize, category: category,
                categoryID: categoryID, name: patch.name, description: patch.description,
                status: state == .applied ? .applied : state == .restorePending ? .restorePending : state == .restored ? .unavailable : .prepared)
        }
    }
}

private extension Data {
    init(hex: String) {
        self.init(Array(stride(from: 0, to: hex.count, by: 2).compactMap {
            let start = hex.index(hex.startIndex, offsetBy: $0)
            let end = hex.index(start, offsetBy: 2)
            return UInt8(hex[start..<end], radix: 16)
        }))
    }
}
