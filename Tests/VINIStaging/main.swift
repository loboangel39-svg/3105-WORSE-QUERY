import Foundation
import CryptoKit

// Host adapter for the existing platform logger, not the transaction engine.
func log(_ message: String) { print(message); fflush(stdout) }
// macOS binding of the existing read-only service method. Real journal/filesystem,
// no container enumeration, no nil stub and no replacement transaction implementation.
enum DevicePatchService {
    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let root = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID:projectID,backupRoot:root)
    }
}


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
func expect(_ condition: Bool, _ name: String) throws { if !condition { print("FAIL " + name); fflush(stdout); throw VINIStagingError.invalidResponse }; print("PASS " + name); fflush(stdout) }

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
        if ProcessInfo.processInfo.environment["VINI_STAGING_SKIP_LIVE"] == "1" {
            print("SKIPPED: live Worker/R2/license scenarios (synthetic fixture mode)")
            print("PASS native macOS synthetic staging fixtures; no live authorization or iPhone execution claimed")
            return
        }
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
                let bytes = try await live.verifiedTestBytes(id:VINIStagingEnvironment.fixtureID)
                try expect(licenses["targetID"] == VINIIsolatedFixture.targetID, "staging policy and pinned fixture target IDs agree")
                let lab = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("build-staging/fixture-evidence",isDirectory:true)
                let trial = VINIIsolatedFixture(directory:lab)
                _ = try await trial.apply(bytes:bytes)
                let backing = VINIDualBackupStore(root:lab.appendingPathComponent("DualBackups"),engineRoot:lab.appendingPathComponent("EngineBackups"))
                let record = try backing.loadRecord(VINIIsolatedFixture.projectID)!
                let a = try backing.verifiedManifest(record,role:"A",stage:"committed")
                _ = try backing.verifiedManifest(record,role:"B",stage:"committed")
                let filename = a.files[0].backupFilename!
                let primary = try backing.receipt(record).journalURL.deletingLastPathComponent().appendingPathComponent(filename)
                let secondary = try backing.transactionRoot(record).appendingPathComponent("B").appendingPathComponent(filename)
                let inodeA = try FileManager.default.attributesOfItem(atPath:primary.path)[.systemFileNumber] as! NSNumber
                let inodeB = try FileManager.default.attributesOfItem(atPath:secondary.path)[.systemFileNumber] as! NSNumber
                try expect(inodeA != inodeB, "A and B original backups use independent inodes")
                _ = try await trial.restore()
                let destination = lab.appendingPathComponent("Container/Documents/acceptance.bin")
                try expect(try Data(contentsOf:destination) == VINIIsolatedFixture.original, "full authorized download/import/Apply/Restore cycle restores original bytes")
                _ = try await trial.apply(bytes:bytes)
                let changed = Data("Owned post-Apply change to preserve\n".utf8)
                try changed.write(to:destination,options:.atomic)
                _ = try await trial.restore()
                let recovered = try FileManager.default.enumerator(at:lab.appendingPathComponent("DualBackups"),includingPropertiesForKeys:nil)!.allObjects.compactMap { $0 as? URL }
                try expect(recovered.contains { (try? Data(contentsOf:$0)) == changed }, "Restore preserves post-Apply changes in independent recovery generation")
                _ = try await trial.apply(bytes:bytes)
                let damagedRecord = try backing.loadRecord(VINIIsolatedFixture.projectID)!
                let damaged = try backing.receipt(damagedRecord).journalURL.deletingLastPathComponent().appendingPathComponent(filename)
                try Data("corrupt owned A backup".utf8).write(to:damaged,options:.atomic)
                _ = try await trial.restore()
                try expect(try Data(contentsOf:destination) == VINIIsolatedFixture.original, "Restore repairs corrupt A from independent B")
                let rollback = VINIIsolatedFixture(directory:lab.appendingPathComponent("InjectedFailure"))
                var failed = false
                do { _ = try await rollback.apply(bytes:bytes,injectFailure:true) } catch { failed = true }
                try expect(failed, "injected Apply failure is not reported as success")
                let partialRoot = lab.appendingPathComponent("PartialRollback",isDirectory:true)
                try FileManager.default.createDirectory(at:partialRoot,withIntermediateDirectories:true)
                let originals = [Data("owned original one".utf8),Data("owned original two".utf8)]
                let rules = (0..<2).map { PatchRule(bundleID:VINIIsolatedFixture.bundleID,relativePath:"file-\($0).bin",replacementFilename:"replacement.bin",replacementData:Data("changed-\($0)".utf8)) }
                for i in 0..<2 { try originals[i].write(to:partialRoot.appendingPathComponent(rules[i].relativePath)) }
                let rp = PatchProject(name:"Owned rollback probe",bundleIdentifiers:[VINIIsolatedFixture.bundleID],rules:rules)
                let rb = VINIDualBackupStore(root:partialRoot.appendingPathComponent("Dual"),engineRoot:partialRoot.appendingPathComponent("Journals"))
                let encodedRollback = try PatchPackageCodec.encodeNew(project:rp,password:nil)
                var rr = VINIOperationRecord(targetID:"package."+rp.id.uuidString,projectID:rp.id,operationID:UUID(),transactionID:nil,previousTransactionID:nil,phase:.preparing,lastVerifiedEnabled:false,desiredEnabled:true,packageDigest:Data(SHA256.hash(data:encodedRollback.data)),plannedRules:rules.map { VINIPlannedRule(id:$0.id,bundleID:$0.bundleID,path:$0.relativePath,digest:Data(SHA256.hash(data:$0.replacementData))) },plannedDirectories:[],roots:[VINIIsolatedFixture.bundleID:try VINIRootIdentity.read(partialRoot)],startedAt:Date())
                var rollbackTriggered = false
                do {
                    _ = try PatchTransaction.apply(project:rp,backupRoot:rb.engineRoot,containerResolver:{ _ in partialRoot },beforeWrite:{ index in
                        if index == 1 {
                            try expect(try Data(contentsOf:partialRoot.appendingPathComponent(rules[0].relativePath)) == rules[0].replacementData,"first file really changed before injected failure")
                            throw VINIPatchFailure.concurrentChange
                        }
                    },beforeMutation:{ receipt in rr.transactionID=receipt.id;rr.phase = .prepared;try rb.save(rr);try rb.preparePair(rr) })
                } catch { rollbackTriggered = true }
                let rollbackReceipt = try rb.receipt(rr)
                let rollbackStatus = try PatchTransaction.journalSnapshot(receipt:rollbackReceipt).status
                rr.phase = .restored; rr.lastVerifiedEnabled = false; rr.desiredEnabled = false; try rb.sealRestored(rr); try rb.save(rr)
                try expect(rollbackTriggered && rollbackStatus == "rolledBack","existing engine rolls back a genuinely partially applied transaction")
                for i in 0..<2 { try expect(try Data(contentsOf:partialRoot.appendingPathComponent(rules[i].relativePath)) == originals[i],"partial rollback original hash restored for file \(i)") }

                try expect(try Data(contentsOf:lab.appendingPathComponent("InjectedFailure/Container/Documents/acceptance.bin")) == VINIIsolatedFixture.original, "existing transaction rollback preserves original bytes")

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
        for (name,expected) in [("paused",VINIStagingError.paused),("revoked",.denied),("expired",.expired),("blocked",.blockedLicense)] {
            guard let key = licenses[name] else { throw VINIStagingError.signedOut }
            do { _ = try await VINIStagingClient(vault:MemoryVault()).login(licenseKey:key); throw VINIStagingError.invalidResponse }
            catch let e as VINIStagingError { try expect(e == expected,"live staging rejects " + name + " license") }
        }
        print("PASS native macOS host tests, live staging API/R2, real Keychain and Swift codec; no iPhone execution claimed")
    }
}
