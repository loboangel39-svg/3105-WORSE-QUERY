import XCTest

final class WQFilesIdentityResolverTests: XCTestCase {
    func testValidBundleIDAndUUID() {
        XCTAssertTrue(ContainerBundleCandidateResolver.isValidBundleIdentifier("com.example.Files"))
        XCTAssertFalse(ContainerBundleCandidateResolver.isValidBundleIdentifier("not-a-bundle-id"))
        XCTAssertNotNil(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
    }

    func testCanonicalAssociationAndUnknownFallback() {
        let path = "/private/var/mobile/Containers/Data/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let original = InstalledApp(bundleID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", name: "Container", containerPath: path, version: "", icon: nil)
        let identity = WQFilesResolvedIdentity(containerPath: path, bundleID: "com.example.Files", displayName: "Files", source: "CSStore2/27.0", storeSignature: "test")
        let merged = WQFilesIdentityMerge.verifiedApps(identities: [path: identity], originalApps: [original])
        XCTAssertEqual(merged.first?.bundleID, "com.example.Files")
        XCTAssertEqual(ContainerPresentationPolicy.shouldShow(bundleID: original.bundleID), false)
    }

    func testContradictionIsRejected() {
        let path = "/private/var/mobile/Containers/Data/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let original = InstalledApp(bundleID: "com.original.app", name: "Original", containerPath: path, version: "", icon: nil)
        let identity = WQFilesResolvedIdentity(containerPath: path, bundleID: "com.other.app", displayName: "Other", source: "CSStore2/27.0", storeSignature: "test")
        XCTAssertTrue(WQFilesIdentityMerge.verifiedApps(identities: [path: identity], originalApps: [original]).isEmpty)
    }

    func testConflictingBundleIDsAreNotMergedTwice() {
        let first = "/private/var/mobile/Containers/Data/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        let second = "/private/var/mobile/Containers/Data/Application/11111111-2222-3333-4444-555555555555"
        let identity = WQFilesResolvedIdentity(containerPath: first, bundleID: "com.example.same", displayName: "One", source: "CSStore2/27.0", storeSignature: "test")
        let duplicate = WQFilesResolvedIdentity(containerPath: second, bundleID: "com.example.same", displayName: "Two", source: "CSStore2/27.0", storeSignature: "test")
        XCTAssertEqual(WQFilesIdentityMerge.verifiedApps(identities: [first: identity, second: duplicate], originalApps: []).count, 1)
    }

    func testDisabledProviderHasNoPresentationSideEffects() {
        XCTAssertTrue(WQFilesIdentityResolver.enabledDefaultsKey.contains("wqfiles.identityResolver"))
        XCTAssertEqual(ContainerDiscoveryMerger.canonicalPath("/var/mobile/Containers/Data/Application/x"), "/private/var/mobile/Containers/Data/Application/x")
    }
}
