# VINI 2.0 RC1 — Source Integration

Modified files:

- `ThreeOneOSFive/views/VINIAuthenticationRoot.swift`: authorized state presents native `ContentView`.
- `ThreeOneOSFive/views/RepositorySourcesView.swift`: adds entry point to real `RemotePatchesView`.
- `ThreeOneOSFive/Authentication/KeychainManager.swift`: adapter over the existing production session record.
- `ThreeOneOSFive/Patches/{RemotePatchService,PatchDownloadService,PatchManager,PatchStorage}.swift`: reused from VINI-IPA.
- `ThreeOneOSFive/helpers/{PatchSyncManager,TokenRefreshManager}.swift`: reused from VINI-IPA.
- `ThreeOneOSFive/views/RemotePatchesView.swift`: reused remote catalog UI.
- `ThreeOneOSFive.xcodeproj/project.pbxproj`: only source membership entries.
- `.github/workflows/build-unsigned-ipa.yml`: required RC1 artifact name.

No Worker, D1/R2, entitlement, bundle identifier, native engine, codec, transaction or backup implementation was changed.
