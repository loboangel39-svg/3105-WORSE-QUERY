import Foundation

struct VINIRemotePatchTarget: Codable {
    let targetID: String
    let category: String
    let packageID: UUID
    let projectID: UUID
    let packageRevision: String
    let packageSHA256: String
    let fileSize: Int
    let requiredPlan: String?
    let availability: String
}
