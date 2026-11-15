import Foundation

// Inert transport contract for the existing Worker + D1, not a trusted catalog.
// Decoding JSON does not authorize Apply, establish a session, or grant a plan.
struct VINIRemoteCatalog: Codable {
    let schemaVersion: Int
    let revision: String
    let targets: [VINIRemoteTarget]
}

struct VINIRemoteTarget: Codable, Identifiable {
    enum Category: String, Codable { case combat, visuals, offsets }
    enum Availability: String, Codable { case available, unavailable, withdrawn }
    let targetID: String
    let category: Category
    let name: String
    let description: String?
    let packageID: UUID
    let projectID: UUID
    let packageRevision: String
    // Lowercase hex SHA-256 binds the revision to the exact imported bytes.
    let packageSHA256: String
    let availability: Availability
    let requiredPlan: String?
    var id: String { targetID }
}

struct VINIRemoteSession: Codable {
    let userID: String
    let userName: String
    let licenseID: String
    let plan: String
    let serverTime: Date
    let expiresAt: Date
    let catalogRevision: String
}

// No URLSession, credential storage or entitlement mutation is introduced here.
// Authority verification, account binding, anti-replay and license refresh must
// be supplied by the real Worker integration before these DTOs can enable Apply.
enum VINIRemoteContract {
    enum ContractError: Error { case invalidCatalog }
    static func decodeCatalog(_ data: Data) throws -> VINIRemoteCatalog {
        let catalog = try JSONDecoder().decode(VINIRemoteCatalog.self, from: data)
        guard catalog.schemaVersion == 1, !catalog.revision.isEmpty else {
            throw ContractError.invalidCatalog
        }
        var targets = Set<String>()
        for entry in catalog.targets {
            guard !entry.targetID.isEmpty, entry.targetID.utf8.count <= 128,
                  !entry.targetID.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  targets.insert(entry.targetID).inserted,
                  !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !entry.packageRevision.isEmpty,
                  entry.packageSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
            else { throw ContractError.invalidCatalog }
        }
        return catalog
    }
}
