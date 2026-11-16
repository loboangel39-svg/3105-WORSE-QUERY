import Foundation

struct VINIPackageCategoryAssociation: Codable, Equatable {
    let userID: String
    let remotePatchID: String
    let packageID: UUID
    let projectID: UUID
    let sha256: String
    let revision: String
    let categoryID: Int
}

struct VINIPackageCategoryStore {
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) { self.fileManager = fileManager }
    private func url() throws -> URL {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VINI", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("package-categories.json")
    }
    func association(userID: String, packageID: UUID, sha256: String) -> VINIPackageCategoryAssociation? {
        guard let file = try? url(), let data = try? Data(contentsOf: file), let values = try? JSONDecoder().decode([VINIPackageCategoryAssociation].self, from: data) else { return nil }
        let matches = values.filter { $0.userID == userID && $0.packageID == packageID && $0.sha256 == sha256 }
        return matches.count == 1 ? matches[0] : nil
    }
    func record(_ value: VINIPackageCategoryAssociation) throws {
        let values = (try? JSONDecoder().decode([VINIPackageCategoryAssociation].self, from: Data(contentsOf: url()))) ?? []
        let filtered = values.filter { !($0.userID == value.userID && $0.packageID == value.packageID && $0.sha256 == value.sha256) }
        try JSONEncoder().encode(filtered + [value]).write(to: try url(), options: .atomic)
    }
}
