import CryptoKit
import Foundation

struct VINIRemoteCacheIdentity: Codable, Equatable {
    let userID: String
    let remotePatchID: String
    let targetID: String
    let packageID: UUID
    let projectID: UUID
    let revision: String
    let sha256: String
    let fileSize: Int
}

struct VINIRemoteCacheRecord: Codable, Equatable {
    let schemaVersion: Int
    let identity: VINIRemoteCacheIdentity
    let packageFilename: String
    let importedPackageURL: String?
}

/// Owns only remote package bytes and metadata. It never touches PatchProjects,
/// Backups, journals or transaction receipts.
struct VINIRemotePackageCache {
    let root: URL
    private let fileManager: FileManager

    init(root: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let root { self.root = root } else {
            let support = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
            self.root = support.appendingPathComponent("VINIRemotePackageCache", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    private func key(for identity: VINIRemoteCacheIdentity) throws -> String {
        let data = try JSONEncoder().encode(identity)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func load(identity: VINIRemoteCacheIdentity) throws -> (Data, VINIRemoteCacheRecord)? {
        let key = try key(for: identity)
        let metaURL = root.appendingPathComponent(key).appendingPathExtension("json")
        guard let record = try? JSONDecoder().decode(VINIRemoteCacheRecord.self, from: Data(contentsOf: metaURL)),
              record.schemaVersion == 1, record.identity == identity else { return nil }
        let packageURL = root.appendingPathComponent(record.packageFilename)
        guard let bytes = try? Data(contentsOf: packageURL), bytes.count == identity.fileSize,
              digest(bytes) == identity.sha256 else { return nil }
        return (bytes, record)
    }

    @discardableResult
    func store(bytes: Data, identity: VINIRemoteCacheIdentity, importedPackageURL: URL? = nil) throws -> VINIRemoteCacheRecord {
        guard bytes.count == identity.fileSize, digest(bytes) == identity.sha256 else { throw CacheError.integrity }
        let key = try key(for: identity)
        let filename = key + ".3105"
        let destination = root.appendingPathComponent(filename)
        let temporary = root.appendingPathComponent("." + UUID().uuidString + ".partial")
        try bytes.write(to: temporary, options: [.atomic, .completeFileProtection])
        guard try Data(contentsOf: temporary).count == identity.fileSize,
              digest(try Data(contentsOf: temporary)) == identity.sha256 else {
            try? fileManager.removeItem(at: temporary); throw CacheError.integrity
        }
        if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
        try fileManager.moveItem(at: temporary, to: destination)
        let record = VINIRemoteCacheRecord(schemaVersion: 1, identity: identity,
            packageFilename: filename, importedPackageURL: importedPackageURL?.path)
        let metaURL = root.appendingPathComponent(key).appendingPathExtension("json")
        try JSONEncoder().encode(record).write(to: metaURL, options: [.atomic, .completeFileProtection])
        return record
    }

    func updateImportURL(identity: VINIRemoteCacheIdentity, importedPackageURL: URL) throws {
        guard let loaded = try load(identity: identity) else { throw CacheError.missing }
        let key = try key(for: identity)
        let record = VINIRemoteCacheRecord(schemaVersion: 1, identity: identity,
            packageFilename: loaded.1.packageFilename, importedPackageURL: importedPackageURL.path)
        try JSONEncoder().encode(record).write(to: root.appendingPathComponent(key).appendingPathExtension("json"), options: [.atomic, .completeFileProtection])
    }

    enum CacheError: Error { case integrity, missing }
    private func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
}
