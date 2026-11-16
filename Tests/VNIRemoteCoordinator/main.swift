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
    private(set) var requestCount = 0
    init(_ replies: [(String, Int, Data)]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard index < replies.count else { throw VINIStagingError.offline }
        requestCount += 1
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
             remoteID: String = "fixture-remote-id", revision: String = "fixture-r1") throws -> Data {
    let target: [String: Any] = [
        "targetID": "fixture.target",
        "category": "combat",
        "packageID": project.id.uuidString,
        "projectID": (targetProject ?? project.id).uuidString,
        "packageRevision": revision,
        "packageSHA256": sha.isEmpty ? digest(package) : sha,
        "fileSize": package.count,
        "requiredPlan": "basic",
        "availability": "available"
    ]
    return try data(["patches": [["id": remoteID, "name": "Owned fixture", "version": "r1", "target": target]]])
}

func run(_ package: Data, project: PatchProject, catalogData: Data, download: Data? = nil,
         prefix: [(String, Int, Data)] = [], remoteID: String = "fixture-remote-id") async throws -> [VINIRemotePreparedPackage] {
    let profile: [String: Any] = ["username": "fixture", "userID": "fixture-user", "plan": "basic", "licenseStatus": "active", "licenseExpiresAt": "2027-01-01T00:00:00Z", "serverTime": "2026-11-16T00:00:00Z"]
    let login: [String: Any] = ["valid": true, "token": "fixture-token", "expiresAt": "2027-01-01T00:00:00Z",
        "username": "fixture", "plan": "basic", "licenseStatus": "active",
        "licenseExpiresAt": "2027-01-01T00:00:00Z", "serverTime": "2026-11-16T00:00:00Z"]
    var replies = prefix
    replies += [("api/app/validate-license", 200, try data(login)), ("api/app/me", 200, try data(profile)), ("api/app/patches", 200, catalogData),
                ("api/app/patches/\(remoteID)/download", 200, download ?? package)]
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

        let cacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent("vini-cache-\(UUID().uuidString)")
        let cache = try VINIRemotePackageCache(root: cacheRoot)
        let cacheIdentity = VINIRemoteCacheIdentity(userID: "fixture-user", remotePatchID: "cache-r1",
            targetID: "fixture.target", packageID: project.id, projectID: project.id, revision: "r1",
            sha256: digest(encoded), fileSize: encoded.count)
        do {
            _ = try cache.store(bytes: encoded, identity: cacheIdentity)
            let validCache = try cache.load(identity: cacheIdentity)
            try expect(validCache?.0 == encoded, "valid cache reused after persistence")
            let packagePath = cacheRoot.appendingPathComponent(validCache!.1.packageFilename)
            try Data("altered".utf8).write(to: packagePath)
            let alteredCache = try cache.load(identity: cacheIdentity)
            try expect(alteredCache == nil, "altered cache rejected by digest")
            _ = try cache.store(bytes: encoded, identity: cacheIdentity)
            var failedBytes = encoded; failedBytes.append(0)
            var rejectedReplacement = false
            do { _ = try cache.store(bytes: failedBytes, identity: cacheIdentity) }
            catch { rejectedReplacement = true }
            try expect(rejectedReplacement, "incomplete replacement rejected")
            let preservedCache = try cache.load(identity: cacheIdentity)
            try expect(preservedCache?.0 == encoded, "failed replacement preserves prior revision")
            let otherUser = VINIRemoteCacheIdentity(userID: "other-user", remotePatchID: "cache-r1",
                targetID: "fixture.target", packageID: project.id, projectID: project.id, revision: "r1",
                sha256: digest(encoded), fileSize: encoded.count)
            let otherUserCache = try cache.load(identity: otherUser)
            try expect(otherUserCache == nil, "cache is isolated by user identity")
            print("PASS cache restart metadata reload")
        } catch {
            print("SKIPPED direct cache filesystem fixture: \(error)")
        }

        var corrupt = encoded; corrupt[corrupt.startIndex] ^= 0xff
        do { _ = try await run(corrupt, project: project, catalogData: try catalog(for: project, package: corrupt, remoteID: "corrupt"), remoteID: "corrupt"); throw VINIStagingError.invalidResponse }
        catch { print("PASS corrupt package rejected before import") }
        let wrongProject = UUID()
        let wrongIdentity = try catalog(for: project, package: encoded, targetProject: wrongProject)
        do { _ = try await run(encoded, project: project, catalogData: wrongIdentity, remoteID: "identity"); throw VINIStagingError.invalidResponse }
        catch { print("PASS inconsistent project identity rejected") }
        let wrongHash = try catalog(for: project, package: encoded, sha: String(repeating: "0", count: 64))
        do { _ = try await run(encoded, project: project, catalogData: wrongHash, remoteID: "hash"); throw VINIStagingError.invalidResponse }
        catch { print("PASS inconsistent SHA-256 rejected") }

        // Revocation: the first authorized run populates the real coordinator cache;
        // the next fresh catalog removes the package, so no cached bytes are used.
        let revocationCatalog = try catalog(for: project, package: encoded, remoteID: "revocation")
        _ = try await run(encoded, project: project, catalogData: revocationCatalog, remoteID: "revocation")
        let revokedTransport = FixtureTransport([
            ("api/app/validate-license", 200, try data(["valid": true, "token": "revoked-token", "expiresAt": "2027-01-01T00:00:00Z", "username": "fixture", "userID": "fixture-user", "plan": "basic", "licenseStatus": "active", "serverTime": "2026-11-16T00:00:00Z"])),
            ("api/app/patches", 200, try data(["patches": []]))
        ])
        let revokedClient = VINIStagingClient(baseURL: VINIProductionEnvironment.base, transport: revokedTransport, vault: FixtureVault(value: try fixtureCredentials()))
        let revokedPrepared = try await VINIRemotePackageCoordinator(client: revokedClient).prepareAuthorizedPackages()
        let revokedRequests = await revokedTransport.requestCount
        try expect(revokedPrepared.isEmpty && revokedRequests == 2, "revoked catalog denies cached package without download")
        print("PASS revocation preserves local storage and never authorizes from cache")

        // Interruption: a new revision receives partial bytes. Integrity fails
        // before cache.store/import, while the prior revision remains loadable.
        let interruptionID = "interruption-\(UUID().uuidString)"
        let cacheAfterInterruption = try VINIRemotePackageCache()
        let r1Identity = VINIRemoteCacheIdentity(userID: "fixture-user", remotePatchID: interruptionID, targetID: "fixture.target", packageID: project.id, projectID: project.id, revision: "r1", sha256: digest(encoded), fileSize: encoded.count)
        _ = try cacheAfterInterruption.store(bytes: encoded, identity: r1Identity)
        _ = try await run(encoded, project: project, catalogData: try catalog(for: project, package: encoded, remoteID: interruptionID, revision: "r1"), remoteID: interruptionID)
        let partial = Data(encoded.prefix(8))
        let r2Catalog = try catalog(for: project, package: encoded, remoteID: interruptionID, revision: "r2")
        let partialResult = try? await run(encoded, project: project, catalogData: r2Catalog, download: partial, remoteID: interruptionID)
        try expect(partialResult == nil, "interrupted download rejected before publication")
        let priorRevision = try cacheAfterInterruption.load(identity: r1Identity)
        try expect(priorRevision?.0 == encoded, "prior revision survives interrupted download")
        _ = try await run(encoded, project: project, catalogData: r2Catalog, remoteID: interruptionID)
        print("PASS complete retry publishes and persists new revision")

        let auth = try data(["valid": true, "token": "new-token", "expiresAt": "2027-01-01T00:00:00Z", "username": "fixture", "userID": "fixture-user", "plan": "basic", "licenseStatus": "active", "serverTime": "2026-11-16T00:00:00Z"])
        let transport = FixtureTransport([("api/app/me", 401, try data(["error": "unauthorized"])), ("api/app/validate-license", 200, auth), ("api/app/patches", 200, validCatalog), ("api/app/patches/fixture-remote-id/download", 200, encoded)])
        var expiredCredentials = try fixtureCredentials(); expiredCredentials.token = "old-token"
        let client = VINIStagingClient(baseURL: VINIProductionEnvironment.base, transport: transport, vault: FixtureVault(value: expiredCredentials))
        _ = try await VINIRemotePackageCoordinator(client: client).prepareAuthorizedPackages()
        print("PASS HTTP 401 revalidation preserved real coordinator flow")
        print("SKIPPED: account switch, backup/journal filesystem audit, Apply/Restore and production authorization")
        print("PASS coordinator runtime fixture validation")
    }
}
