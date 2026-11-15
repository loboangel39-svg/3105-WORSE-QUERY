import Foundation

// Pure metadata tests on the build host. No iOS application, container access,
// exploitation, virtual device or UI is executed by this test program.
var checks = 0
func expect(_ value: Bool, _ label: String) {
    precondition(value, label)
    checks += 1
}
func resolve(_ major: Int, _ minor: Int, _ patch: Int, _ build: String,
             _ release: VINIRelease? = nil) -> VINICompatibility {
    VINICompatibilityResolver.resolve(major: major, minor: minor, patch: patch,
        build: build, release: release)
}
// Synthetic final-build fixtures test policy bounds, not real device support.
expect(resolve(17, 0, 0, "21A100").kernel == .kernel, "17 lower")
expect(resolve(17, 7, 0, "21H100").documented, "17 upper")
expect(!resolve(17, 7, 1, "21H101").documented, "17 above explicit upper")
expect(!resolve(17, 8, 0, "21J100").documented, "17 future")
expect(resolve(18, 0, 0, "22A100").kernel == .kernel, "18 lower")
expect(resolve(18, 7, 1, "22H100").documented, "18 upper")
expect(!resolve(18, 7, 2, "22H101").documented, "18 future")
expect(resolve(26, 0, 0, "23A100").sandbox == .badQuery, "26 lower")
expect(resolve(26, 6, 1, "23G100").fallback == .worseQuery, "26 fallback")
expect(resolve(26, 6, 2, "23G101").sandbox == .worseQuery, "26 transition")
expect(resolve(26, 7, 2, "23H100").sandbox == .worseQuery, "26 upper")
expect(!resolve(26, 7, 3, "23H101").documented, "26 future")
for (beta, _, build) in ExploitSupportPolicy.verifiedIOS27Builds {
    expect(VINICompatibilityResolver.release(build: build, major: 27) == .beta(beta), "seed identity")
    expect(resolve(27, 0, 0, build).sandbox == .badQuery, "27 beta 1-4")
    expect(!resolve(27, 0, 0, build, .final).documented, "seed cannot claim final")
}
// Synthetic seed build: authoritative stage is explicitly supplied by the test.
expect(resolve(27, 0, 0, "24A9999x", .beta(5)).sandbox == .worseQuery, "27 beta 5 policy")
expect(!resolve(27, 0, 0, "24A9999x").documented, "unknown seed requires evidence")
expect(resolve(27, 2, 1, "24B156").sandbox == .worseQuery, "user-specified 27.2.1 build")
expect(resolve(27, 2, 1, "24B156").kernel == .none, "no kernel execution claim")
expect(!resolve(27, 2, 2, "24C100").documented, "27 final upper")
expect(!resolve(27, 3, 0, "24D100").documented, "27.3 final not documented")
expect(resolve(27, 3, 0, "24D9999x", .beta(1)).sandbox == .worseQuery, "27.3 beta 1 policy")
expect(!resolve(27, 3, 0, "24D9999x", .beta(2)).documented, "27.3 beta 2 unknown")
expect(!resolve(27, 3, 0, "24D9999x").documented, "unknown beta build not inferred")
expect(!resolve(28, 0, 0, "25A100").documented, "future major")
expect(!resolve(27, -1, 0, "24A100").documented, "negative version")
expect(!resolve(27, 2, 1, "").documented, "missing build")
expect(!resolve(27, 2, 1, "unknown").documented, "invalid build")
expect(!resolve(27, 2, 1, "23A100").documented, "wrong build train")

let package = UUID().uuidString
let entry: [String: Any] = ["targetID": "vini.aim_drag", "category": "combat",
    "name": "Assigned target", "packageID": package, "projectID": package,
    "packageRevision": "r1", "packageSHA256": String(repeating: "a", count: 64),
    "availability": "available"]
func catalog(_ entries: [[String: Any]], schema: Int = 1) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["schemaVersion": schema,
        "revision": "catalog-r1", "targets": entries])
}
let decoded = try VINIRemoteContract.decodeCatalog(catalog([entry]))
expect(decoded.targets.first?.targetID == "vini.aim_drag", "stable target identity")
expect(decoded.targets.first?.packageID.uuidString == package, "explicit package association")
expect(decoded.targets.first?.description == nil, "no invented description")
func rejected(_ data: Data) -> Bool {
    do { _ = try VINIRemoteContract.decodeCatalog(data); return false } catch { return true }
}
expect(rejected(try catalog([entry, entry])), "duplicate target rejected")
expect(rejected(try catalog([entry], schema: 2)), "unknown schema rejected")
var corrupt = entry; corrupt["packageSHA256"] = "not-a-hash"
expect(rejected(try catalog([corrupt])), "invalid revision hash rejected")
print("PASS: \(checks) pure metadata checks; no iOS functional validation performed")
