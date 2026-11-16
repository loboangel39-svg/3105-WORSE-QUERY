import CryptoKit
import Foundation

struct VINIRemotePreparedPackage: Codable, Equatable {
    let remotePatchID: String
    let targetID: String
    let packageID: UUID
    let projectID: UUID
    let revision: String
    let sha256: String
    let fileSize: Int
    let packageURL: URL
    let categoryID: Int?
}

/// Coordinates remote catalog/import state without changing the codec or transaction engine.
actor VINIRemotePackageCoordinator {
    enum CoordinatorError: Error { case noTarget, invalidIdentity, integrity, locked, staleAuthorization }
    private let client: VINIStagingClient
    private let fileManager: FileManager
    private let cache: VINIRemotePackageCache
    private let categoryStore: VINIPackageCategoryStore
    private(set) var skippedNoTarget = 0
    private(set) var skippedLocked = 0
    private(set) var skippedFailed = 0
    init(client: VINIStagingClient, fileManager: FileManager = .default) {
        self.client = client; self.fileManager = fileManager; self.cache = (try! VINIRemotePackageCache(fileManager: fileManager)); self.categoryStore = VINIPackageCategoryStore(fileManager: fileManager)
    }

    /// Production wiring uses the single definitive Worker. Tests inject the
    /// same client with a synthetic transport while retaining this base URL.
    init(fileManager: FileManager = .default) {
        self.client = VINIStagingClient(baseURL: VINIProductionEnvironment.base)
        self.fileManager = fileManager; self.cache = (try! VINIRemotePackageCache(fileManager: fileManager)); self.categoryStore = VINIPackageCategoryStore(fileManager: fileManager)
    }

    func prepareAuthorizedPackages() async throws -> [VINIRemotePreparedPackage] {
        let profile = try await client.profile()
        let entries = try await client.catalog()
        var prepared: [VINIRemotePreparedPackage] = []
        for entry in entries {
            guard let target = entry.target else { skippedNoTarget += 1; continue }
            guard target.availability == "available" else { continue }
            do { prepared.append(try await prepare(entry: entry, target: target, userID: profile.stableUserID)) }
            catch {
                if case CoordinatorError.locked = error { skippedLocked += 1 }
                else { skippedFailed += 1 }
            }
        }
        return prepared
    }

    private func prepare(entry: VINIStagingPatch, target: VINIRemotePatchTarget, userID: String) async throws -> VINIRemotePreparedPackage {
        guard target.packageSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              target.targetID.isEmpty == false else { throw CoordinatorError.invalidIdentity }
        let identity = VINIRemoteCacheIdentity(userID: userID, remotePatchID: entry.id, targetID: target.targetID,
            packageID: target.packageID, projectID: target.projectID, revision: target.packageRevision,
            sha256: target.packageSHA256, fileSize: target.fileSize)
        let bytes: Data
        var authorizedKey: Data?
        if let cached = try cache.load(identity: identity) { bytes = cached.0 }
        else {
            let download = try await client.downloadPackageWithMetadata(id: entry.id)
            bytes = download.data
            authorizedKey = download.contentKey
            guard bytes.count == target.fileSize else { throw CoordinatorError.integrity }
            guard SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == target.packageSHA256 else { throw CoordinatorError.integrity }
            try cache.store(bytes: bytes, identity: identity)
        }
        guard bytes.count > 0, bytes.count == target.fileSize else { throw CoordinatorError.integrity }
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard digest == target.packageSHA256 else { throw CoordinatorError.integrity }
        let summary = try PatchPackageCodec.inspect(bytes)
        guard summary.packageID == target.packageID else { throw CoordinatorError.invalidIdentity }
        if let keyValue = authorizedKey { try PatchKeyStore.store(keyValue, for: summary) }
        let decoded: DecodedPatchPackage
        if let key = try PatchKeyStore.load(for: summary) {
            decoded = try PatchPackageCodec.decode(bytes, contentKey: key)
        } else {
            guard !summary.isPasswordProtected else { skippedLocked += 1; throw CoordinatorError.locked }
            decoded = try PatchPackageCodec.decode(bytes, password: nil)
        }
        guard decoded.project.id == target.projectID else { throw CoordinatorError.invalidIdentity }
        let url = try PatchProjectLibrary.save(data: bytes, projectName: decoded.project.name, fileManager: fileManager)
        let categoryID = VINIProductionCategoryRegistry.categoryID(for: target.category)
        if let categoryID { try categoryStore.record(VINIPackageCategoryAssociation(userID: userID, remotePatchID: entry.id, packageID: target.packageID, projectID: target.projectID, sha256: digest, revision: target.packageRevision, categoryID: categoryID)) }
        return VINIRemotePreparedPackage(remotePatchID: entry.id, targetID: target.targetID, packageID: target.packageID,
            projectID: target.projectID, revision: target.packageRevision, sha256: digest, fileSize: bytes.count, packageURL: url, categoryID: categoryID)
    }

}
