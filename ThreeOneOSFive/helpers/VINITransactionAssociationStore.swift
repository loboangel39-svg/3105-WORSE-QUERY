import Foundation

struct VINITransactionAssociation: Codable, Equatable {
    let targetID: String
    let projectID: UUID
    let packageDigest: String
    let transactionID: UUID?
    let userID: String
    let updatedAt: Date
}

struct VINITransactionAssociationStore {
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) { self.fileManager = fileManager }
    private func fileURL() throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VINI", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("transaction-associations.json")
    }
    func all() -> [VINITransactionAssociation] {
        guard let url = try? fileURL(), let data = try? Data(contentsOf: url), let values = try? JSONDecoder().decode([VINITransactionAssociation].self, from: data) else { return [] }
        return values
    }
    func recordIntent(targetID: String, projectID: UUID, packageDigest: String, userID: String) throws {
        try save(VINITransactionAssociation(targetID: targetID, projectID: projectID, packageDigest: packageDigest, transactionID: nil, userID: userID, updatedAt: Date()))
    }
    func recordApplied(targetID: String, projectID: UUID, packageDigest: String, transactionID: UUID, userID: String) throws {
        try save(VINITransactionAssociation(targetID: targetID, projectID: projectID, packageDigest: packageDigest, transactionID: transactionID, userID: userID, updatedAt: Date()))
    }
    func exact(targetID: String, projectID: UUID, packageDigest: String, userID: String) -> VINITransactionAssociation? {
        let matches = all().filter { $0.targetID == targetID && $0.projectID == projectID && $0.packageDigest == packageDigest && $0.userID == userID && $0.transactionID != nil }
        return matches.count == 1 ? matches[0] : nil
    }
    private func save(_ value: VINITransactionAssociation) throws {
        let values = all().filter { !($0.targetID == value.targetID && $0.projectID == value.projectID && $0.userID == value.userID) } + [value]
        try JSONEncoder().encode(values).write(to: try fileURL(), options: .atomic)
    }
}
