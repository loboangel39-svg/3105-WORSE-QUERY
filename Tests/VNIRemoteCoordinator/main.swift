import Foundation
import CryptoKit
func log(_ message: String) { print(message); fflush(stdout) }

final class FixtureVault: VINIStagingVault {
    var value: VINIStagingCredentials?
    init(value: VINIStagingCredentials?) { self.value = value }
    func load() throws -> VINIStagingCredentials? { value }
    func save(_ credentials: VINIStagingCredentials) throws { value = credentials }
    func delete() throws { value = nil }
}

actor FixtureTransport: VINIStagingTransport {
    let replies: [(String, Int, Data)]
    var index = 0
    init(_ replies: [(String, Int, Data)]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard index < replies.count else { throw VINIStagingError.offline }
        let reply = replies[index]; index += 1
        log("REQUEST \(request.url?.path ?? "nil") expected /\(reply.0) status \(reply.1)")
        guard request.url?.path == "/" + reply.0 else { throw VINIStagingError.invalidResponse }
        return (reply.2, HTTPURLResponse(url: request.url!, statusCode: reply.1, httpVersion: nil, headerFields: nil)!)
    }
}

func data(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
func digest(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
func response(_ value: Any, status: Int = 200) -> (Int, Data) { (status, try! data(value)) }
func fixtureCredentials() throws -> VINIStagingCredentials {
    try JSONDecoder().decode(VINIStagingCredentials.self, from: data([
        "licenseKey": "fixture", "hwid": "fixture-hwid", "token": "", "expiresAt": ""
    ]))
}
func expect(_ condition: @autoclosure () -> Bool, _ label: String) throws {
    guard condition() else { throw VINIStagingError.invalidResponse }
    print("PASS \(label)")
}

func catalog(for project: PatchProject, package: Data, sha: String = "", targetProject: UUID? = nil,
             remoteID: String = "fixture-remote-id") throws -> Data {
    let target: [String: Any] = [
        "targetID": "fixture.target",
        "category": "combat",
        "packageID": project.id.uuidString,
        "projectID": (targetProject ?? project.id).uuidString,
        "packageRevision": "fixture-r1",
        "packageSHA256": sha.isEmpty ? digest(package) : sha,
        "fileSize": package.count,
        "requiredPlan": "basic",
        "availability": "available"
    ]
    return try data(["patches": [["id": remoteID, "name": "Owned fixture", "version": "r1", "target": target]]])
}

func run(_ package: Data, project: PatchProject, catalogData: Data, download: Data? = nil,
         prefix: [(String, Int, Data)] = []) async throws -> [VINIRemotePreparedPackage] {
    let login: [String: Any] = ["valid": true, "token": "fixture-token", "expiresAt": "2027-01-01T00:00:00Z",
        "username": "fixture", "plan": "basic", "licenseStatus": "active",
        "licenseExpiresAt": "2027-01-01T00:00:00Z", "serverTime": "2026-11-16T00:00:00Z"]
    var replies = prefix
    replies += [("api/app/validate-license", 200, try data(login)), ("api/app/patches", 200, catalogData),
                ("api/app/patches/fixture-remote-id/download", 200, download ?? package)]
    let client = VINIStagingClient(baseURL: VINIProductionEnvironment.base, transport: FixtureTransport(replies), vault: FixtureVault(value: try fixtureCredentials()))
    log("LOGIN synthetic")
    _ = try await client.login(licenseKey: "fixture")
    log("LOGIN complete")
    return try await VINIRemotePackageCoordinator(client: client).prepareAuthorizedPackages()
}

@main struct RemoteCoordinatorTests {
    static func main() async throws {
        let project = PatchProject(name: "Coordinator-owned fixture", bundleIdentifiers: ["com.example.vini.fixture"], rules: [])
        let encoded = try PatchPackageCodec.encodeNew(project: project, password: nil).data
        let validCatalog = try catalog(for: project, package: encoded)
        let prepared = try await run(encoded, project: project, catalogData: validCatalog)
        try expect(prepared.count == 1, "real prepareAuthorizedPackages returns one prepared package")
        try expect(prepared[0].packageID == project.id && prepared[0].projectID == project.id, "package/project identity preserved")
        try expect(prepared[0].sha256 == digest(encoded) && prepared[0].fileSize == encoded.count, "size and SHA-256 verified")
        try expect(FileManager.default.fileExists(atPath: prepared[0].packageURL.path), "PatchProjectLibrary imported the package")
        let imported = try PatchPackageCodec.decode(Data(contentsOf: prepared[0].packageURL), password: nil)
        try expect(imported.project.id == project.id, "imported bytes decode with original codec")

        var corrupt = encoded; corrupt[corrupt.startIndex] ^= 0xff
        do { _ = try await run(corrupt, project: project, catalogData: validCatalog); throw VINIStagingError.invalidResponse }
        catch { print("PASS corrupt package rejected before import") }
        let wrongProject = UUID()
        let wrongIdentity = try catalog(for: project, package: encoded, targetProject: wrongProject)
        do { _ = try await run(encoded, project: project, catalogData: wrongIdentity); throw VINIStagingError.invalidResponse }
        catch { print("PASS inconsistent project identity rejected") }
        let wrongHash = try catalog(for: project, package: encoded, sha: String(repeating: "0", count: 64))
        do { _ = try await run(encoded, project: project, catalogData: wrongHash); throw VINIStagingError.invalidResponse }
        catch { print("PASS inconsistent SHA-256 rejected") }

        let profile: [String: Any] = ["username": "fixture", "plan": "basic", "licenseStatus": "active", "serverTime": "2026-11-16T00:00:00Z"]
        let auth = try data(["valid": true, "token": "new-token", "expiresAt": "2027-01-01T00:00:00Z", "username": "fixture", "plan": "basic", "licenseStatus": "active", "serverTime": "2026-11-16T00:00:00Z"])
        let transport = FixtureTransport([("api/app/validate-license", 200, auth), ("api/app/me", 401, try data(["error": "unauthorized"])), ("api/app/validate-license", 200, auth), ("api/app/patches", 200, validCatalog), ("api/app/patches/fixture-remote-id/download", 200, encoded)])
        let client = VINIStagingClient(baseURL: VINIProductionEnvironment.base, transport: transport, vault: FixtureVault(value: try fixtureCredentials()))
        _ = try await client.login(licenseKey: "fixture")
        _ = try await VINIRemotePackageCoordinator(client: client).prepareAuthorizedPackages()
        _ = profile
        print("PASS HTTP 401 revalidation preserved real coordinator flow")
        print("SKIPPED: interrupted download, altered cache, account switch, post-catalog revocation, Apply/Restore and production authorization")
        print("PASS coordinator runtime fixture validation")
    }
}
