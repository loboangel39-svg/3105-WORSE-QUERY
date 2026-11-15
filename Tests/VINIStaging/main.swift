import Foundation
import CryptoKit

final class MemoryVault: VINIStagingVault {
    var value: VINIStagingCredentials?
    var rejectSave = false
    init(_ value: VINIStagingCredentials? = nil) { self.value = value }
    func load() throws -> VINIStagingCredentials? { value }
    func save(_ credentials: VINIStagingCredentials) throws { if rejectSave { throw VINIStagingError.keychain }; value = credentials }
    func delete() throws { value = nil }
}
actor TestTransport: VINIStagingTransport {
    var replies: [(Int, Data)]
    var calls: [String] = []
    init(_ replies: [(Int, Data)]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        calls.append(request.url!.path)
        guard !replies.isEmpty else { throw VINIStagingError.invalidResponse }
        let r = replies.removeFirst()
        try await Task.sleep(nanoseconds: 20_000_000)
        if r.0 == 0 { throw VINIStagingError.offline }
        return (r.1, HTTPURLResponse(url: request.url!, statusCode: r.0, httpVersion: nil, headerFields: nil)!)
    }
    func count(_ path: String) -> Int { calls.filter { $0 == path }.count }
}
func json(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
func record() -> VINIStagingCredentials { VINIStagingCredentials(licenseKey: "SYNTHETIC", hwid: "synthetic", token: "old-token", expiresAt: "2000-01-01T00:00:00Z") }
func response() -> [String: Any] { ["username":"Synthetic","plan":"basic","licenseStatus":"active","licenseExpiresAt":"2026-11-22T00:00:00Z","serverTime":"2026-11-15T00:00:00Z"] }
func loginResponse() -> [String: Any] { response().merging(["valid":true,"token":"new-token","expiresAt":"2026-11-16T00:00:00Z"]) { _,new in new } }
func expect(_ condition: Bool, _ name: String) throws { if !condition { throw VINIStagingError.invalidResponse }; print("PASS " + name) }

@main struct StagingTests {
    static func main() async throws {
        let profile = try json(response()), login = try json(loginResponse())
        let vault = MemoryVault(record()), transport = TestTransport([(200, profile)])
        let client = VINIStagingClient(transport: transport, vault: vault)
        try await withThrowingTaskGroup(of: VINIStagingProfile.self) { group in
            for _ in 0..<20 { group.addTask { try await client.profile() } }
            for try await value in group { guard value.plan == "basic" else { throw VINIStagingError.invalidResponse } }
        }
        try expect(await transport.count("/api/app/me") == 1, "concurrent profile coalesces and current token needs no login")
        let expiredVault = MemoryVault(record()), expiredTransport = TestTransport([(401, try json(["error":"unauthorized"])),(200,login)])
        _ = try await VINIStagingClient(transport: expiredTransport, vault: expiredVault).profile()
        try expect(expiredVault.value?.token == "new-token", "expired token explicitly revalidated and replacement saved")
        try expect(await expiredTransport.count("/api/app/validate-license") == 1, "one login only")
        for (message, expected) in [("Account paused", VINIStagingError.paused),("Account inactive",.denied),("License expired",.expired)] {
            let v = MemoryVault(record()), t = TestTransport([(401,try json(["error":"unauthorized"])),(403,try json(["error":message]))])
            let c = VINIStagingClient(transport:t,vault:v)
            do { _ = try await c.profile(); throw VINIStagingError.invalidResponse } catch let e as VINIStagingError { try expect(e == expected, "rejected license state " + message) }
            do { _ = try await c.profile(); throw VINIStagingError.invalidResponse } catch let e as VINIStagingError { try expect(e == .rateLimited, "revalidation cooldown prevents login loop") }
            try expect(v.value?.token == "", "rejected old token removed from Keychain record")
        }
        let offlineVault = MemoryVault(record()), offlineTransport = TestTransport([(0,Data()),(200,profile)])
        let recovering = VINIStagingClient(transport:offlineTransport,vault:offlineVault)
        do { _ = try await recovering.profile(); throw VINIStagingError.invalidResponse } catch let e as VINIStagingError { try expect(e == .offline, "offline state distinguished") }
        _ = try await recovering.profile()
        try expect(await offlineTransport.count("/api/app/validate-license") == 0, "connection recovery reuses token without login")
        let failedVault = MemoryVault(); failedVault.rejectSave = true
        do { _ = try await VINIStagingClient(transport:TestTransport([(200,login)]),vault:failedVault).login(licenseKey:"SYNTHETIC"); throw VINIStagingError.invalidResponse }
        catch let e as VINIStagingError { try expect(e == .keychain, "Keychain failure does not establish verified session") }
        let switchVault = MemoryVault(record())
        let switched = VINIStagingClient(transport:TestTransport([(403,try json(["error":"Account paused"]))]),vault:switchVault)
        do { _ = try await switched.login(licenseKey:"OTHER-SYNTHETIC"); throw VINIStagingError.invalidResponse }
        catch let e as VINIStagingError { try expect(e == .paused,"rejected account switch reported") }
        try expect(switchVault.value?.licenseKey == "OTHER-SYNTHETIC" && switchVault.value?.token == "", "rejected account switch cannot resurrect old session")
        let logoutVault = MemoryVault(record())
        let stale = VINIStagingClient(transport:TestTransport([(200,profile)]),vault:logoutVault)
        let pending = Task { try await stale.profile() }; try await Task.sleep(nanoseconds:5_000_000); try await stale.logout()
        var staleRejected = false
        do { _ = try await pending.value } catch { staleRejected = true }
        try expect(staleRejected, "logout prevents stale response restoring session")
        try expect(logoutVault.value?.hwid == "synthetic" && logoutVault.value?.token == "" && logoutVault.value?.licenseKey == "", "logout removes credentials but preserves device identity")
        do { _ = try await stale.profile(); throw VINIStagingError.invalidResponse }
        catch let e as VINIStagingError { try expect(e == .signedOut,"HWID alone never establishes a session") }
        let kc = VINIStagingKeychain(service:"vini.staging.native-test."+UUID().uuidString)
        try kc.save(record()); try expect(try kc.load()?.token == "old-token", "real macOS Keychain read after write")
        var replacement = record(); replacement.token = "replacement"
        try kc.save(replacement); try expect(try kc.load()?.token == "replacement", "real macOS Keychain update")
        try kc.delete(); try expect(try kc.load() == nil, "real macOS Keychain deletion")
        let project = PatchProject(name:"Synthetic codec test", bundleIdentifiers:["com.example.vini.test"],rules:[])
        let encoded = try PatchPackageCodec.encodeNew(project:project,password:nil)
        try expect(try PatchPackageCodec.decode(encoded.data,password:nil).project.id == project.id, "unchanged Swift codec roundtrip")
        var corrupt = encoded.data; corrupt[corrupt.count-1] ^= 1
        var corruptRejected = false
        do { _ = try PatchPackageCodec.decode(corrupt,password:nil) } catch { corruptRejected = true }
        try expect(corruptRejected, "corrupt package rejected")
        guard let fixture = ProcessInfo.processInfo.environment["VINI_STAGING_TEST_LICENSES"],
              let data = fixture.data(using:.utf8), let licenses = try JSONSerialization.jsonObject(with:data) as? [String:String]
        else { throw VINIStagingError.signedOut }
        for plan in ["basic","pro"] {
            guard let key = licenses[plan] else { throw VINIStagingError.signedOut }
            let liveVault = MemoryVault(VINIStagingCredentials(licenseKey:key,hwid:"TEST2D-ci-"+plan,token:"",expiresAt:""))
            let live = VINIStagingClient(vault:liveVault)
            let p = try await live.login(licenseKey:key); try expect(p.plan == plan,"live staging login plan " + plan)
            let patches = try await live.catalog()
            if plan == "pro" {
                try expect(patches.contains { $0.id == VINIStagingEnvironment.fixtureID },"assigned PRO fixture in live catalog")
                guard let revokedID = licenses["revokedPatchID"] else { throw VINIStagingError.invalidResponse }
                try expect(!patches.contains { $0.id == revokedID },"revoked assigned patch excluded from live catalog")
                var blockedRequest = URLRequest(url:VINIStagingEnvironment.base.appendingPathComponent("api/app/patches/"+revokedID+"/download"))
                blockedRequest.setValue("Bearer "+liveVault.value!.token,forHTTPHeaderField:"Authorization")
                let (_, blockedResponse) = try await VINIStagingHTTP().send(blockedRequest)
                try expect(blockedResponse.statusCode == 403,"revoked patch direct R2 request denied")
                let name = try await live.downloadTestPackage(id:VINIStagingEnvironment.fixtureID)
                try expect(!name.isEmpty,"live R2 bytes match SHA256 and unchanged Swift codec decodes fixture")
                let restored = VINIStagingClient(vault:liveVault)
                try expect(try await restored.profile().username == p.username,"session restored without new login")
                let deviceID = liveVault.value!.hwid
                try await restored.logout()
                let relogged = VINIStagingClient(vault:liveVault)
                _ = try await relogged.login(licenseKey:key)
                try expect(liveVault.value?.hwid == deviceID,"live logout/relogin retains server device binding")
            } else {
                try expect(!patches.contains { $0.id == VINIStagingEnvironment.fixtureID },"BASIC does not receive PRO fixture")
                do { _ = try await live.downloadTestPackage(id:VINIStagingEnvironment.fixtureID); throw VINIStagingError.invalidResponse }
                catch let e as VINIStagingError { try expect(e == .denied,"BASIC direct PRO download denied by server") }
            }
        }
        guard let unassignedKey = licenses["unassigned"] else { throw VINIStagingError.signedOut }
        let unassigned = VINIStagingClient(vault:MemoryVault(VINIStagingCredentials(licenseKey:unassignedKey,hwid:"TEST2D-ci-unassigned",token:"",expiresAt:"")))
        _ = try await unassigned.login(licenseKey:unassignedKey)
        try expect(try await unassigned.catalog().isEmpty,"PRO has no automatic assignments")
        do { _ = try await unassigned.downloadTestPackage(id:VINIStagingEnvironment.fixtureID); throw VINIStagingError.invalidResponse }
        catch let e as VINIStagingError { try expect(e == .denied,"unassigned PRO download denied") }
        for (name,expected) in [("paused",VINIStagingError.paused),("revoked",.denied)] {
            guard let key = licenses[name] else { throw VINIStagingError.signedOut }
            do { _ = try await VINIStagingClient(vault:MemoryVault()).login(licenseKey:key); throw VINIStagingError.invalidResponse }
            catch let e as VINIStagingError { try expect(e == expected,"live staging rejects " + name + " license") }
        }
        print("PASS native macOS host tests, live staging API/R2, real Keychain and Swift codec; no iPhone execution claimed")
    }
}
