import SwiftUI
import UIKit

struct AppDataBrowserView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var refresh = SilentAppDataRefresh.shared
    private var apps: [InstalledApp] { refresh.apps }
    @State private var searchText = ""
    @State private var workspaceURL: URL?
    @Binding private var tabSession: FilesTabSession
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(
        tabSession: Binding<FilesTabSession>,
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        _tabSession = tabSession
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        let q = searchText.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
    }

    private var overlayState: AppBrowserOverlayState {
        if apps.isEmpty { return .empty }
        if filteredApps.isEmpty { return .noResults }
        return .none
    }

    private var interfaceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.20)
    }

    var body: some View {
        navigationContent(tabID: tabSession.selectedTabID)
            .id(tabSession.selectedTabID)

    }

    private func navigationContent(tabID: UUID) -> some View {
        NavigationStack(path: navigationPath(for: tabID)) {
            appList
            .navigationTitle(language.text("browser.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    FilesTabToolbarButton(session: $tabSession)
                }
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .onAppear {
                if workspaceURL == nil {
                    workspaceURL = try? PatchWorkspaceService.documentsRootURL()
                    _ = try? PatchWorkspaceService.patchesRootURL()
                }
                refresh.open()
            }
            .navigationDestination(for: FileBrowserDestination.self) { destination in
                if destination.startPath == destination.containerPath {
                    FileBrowserView(
                        containerPath: destination.containerPath,
                        title: destination.title,
                        bundleID: destination.bundleID,
                        filesTabSession: $tabSession
                    )
                } else {
                    FileBrowserView(
                        containerPath: destination.containerPath,
                        startPath: destination.startPath,
                        title: destination.title,
                        bundleID: destination.bundleID,
                        filesTabSession: $tabSession
                    )
                }
            }
        }
    }

    private func navigationPath(for tabID: UUID) -> Binding<[FileBrowserDestination]> {
        Binding(
            get: { tabSession.navigationPath(for: tabID) },
            set: { tabSession.setNavigationPath($0, for: tabID) }
        )
    }

    private var appList: some View {
        VStack(spacing: 0) {
            if horizontalSizeClass == .regular {
                FilesTabStrip(session: $tabSession)
            }
            AppSearchField(
                text: $searchText,
                prompt: language.text("browser.search"),
                clearLabel: language.text("common.clear")
            )
            Divider()
            appRows
        }
    }

    private var appRows: some View {
        List {
            if let workspaceURL {
                Section(language.text("browser.workspace")) {
                    let workspaceDestination = FileBrowserDestination(
                        containerPath: workspaceURL.path,
                        startPath: workspaceURL.path,
                        title: "3105",
                        bundleID: nil
                    )
                    NavigationLink(value: workspaceDestination) {
                        HStack(spacing: 10) {
                            AppRowIcon(systemName: "folder.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("3105")
                                    .font(.subheadline.weight(.semibold))
                                Text(language.text("browser.workspace_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .contextMenu {
                        openInNewTabButton(workspaceDestination)
                    }
                }
            }
            Section {
                ForEach(filteredApps) { app in
                    if app.containerPath.isEmpty {
                        appRow(app)
                    } else {
                        let appDestination = FileBrowserDestination(
                            containerPath: app.containerPath,
                            startPath: app.containerPath,
                            title: app.displayName,
                            bundleID: app.bundleID
                        )
                        NavigationLink(value: appDestination) {
                            appRow(app)
                        }
                        .contextMenu {
                            openInNewTabButton(appDestination)
                        }
                    }
                }
            } header: {
                HStack(spacing: 8) {
                    Text(language.text("browser.apps_count", Int64(filteredApps.count)))
                    Spacer()

                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 48)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            Group {
                switch overlayState {
                case .empty:
                    emptyView
                case .noResults:
                    searchEmptyView
                case .none:
                    EmptyView()
                }
            }
            .transition(.opacity)
            .animation(interfaceAnimation, value: overlayState)
        }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            BrowserAppIcon(app: app)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                Text(app.bundleID)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if !app.version.isEmpty {
                Text(app.version)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
    }

    private func openInNewTabButton(_ destination: FileBrowserDestination) -> some View {
        Button {
            tabSession.openTab(navigationPath: [destination])
        } label: {
            Label(language.text("browser.open_new_tab"), systemImage: "square.on.square")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("browser.empty"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }

    private var searchEmptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("browser.search_empty"))
                .font(.subheadline.weight(.medium))
            Text(language.text("browser.search_apps_empty_message"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }


}

private enum AppBrowserOverlayState: Equatable {
    case empty
    case noResults
    case none
}

struct BrowserAppIcon: View {
    let app: InstalledApp
    @State private var resolvedIcon: UIImage?
    @State private var didRequestIcon = false

    init(app: InstalledApp) {
        self.app = app
        _resolvedIcon = State(initialValue: app.icon)
    }

    var body: some View {
        Group {
            if let resolvedIcon {
                Image(uiImage: resolvedIcon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app")
                    .font(.system(size: AppTheme.rowIconSize, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: AppTheme.appIconSize, height: AppTheme.appIconSize)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityHidden(true)
        .onAppear {
            guard resolvedIcon == nil, !didRequestIcon else { return }
            didRequestIcon = true
            let bundleID = app.bundleID
            DispatchQueue.global(qos: .utility).async {
                let icon = iconForBundleID(bundleID)
                DispatchQueue.main.async {
                    resolvedIcon = icon
                }
            }
        }
    }
}

// No presentation, navigation or permission UI belongs to the refresh owner.
private final class SilentAppDataRefresh: ObservableObject {
    static let shared = SilentAppDataRefresh()
    @Published private(set) var apps: [InstalledApp] = []
    private var isLoading = false
    private var isResolving = false
    private var reloadToken = UUID()
    private var retryAttempt: UInt = 0
    private var lastFinished = Date.distantPast
    private var pendingRetry: DispatchWorkItem?
    private var opened = false
    private var observers: [NSObjectProtocol] = []

    private init() {
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.opened else { return }; self.open()
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pendingRetry?.cancel(); self?.pendingRetry = nil
        })
    }
    func open() {
        let wasOpened = opened
        opened = true
        guard !isResolving, pendingRetry == nil,
              !wasOpened || Date().timeIntervalSince(lastFinished) >= 60 || (WQIntegratedScanState()["status"] as? String) == "stopped" else { return }
        retryAttempt = 0
        reload()
    }
    private func scheduleRetry(transient: Bool) {
        let delay = WQIntegratedRefreshRetryDelay(retryAttempt, transient)
        guard delay >= 0 else {
            if transient { log("refresh.internal: retry budget exhausted; cached rows retained") }
            return
        }
        retryAttempt += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingRetry = nil
            self.reload()
        }
        pendingRetry = work
        log("refresh.internal: transient failure; retry \(retryAttempt) in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func mergeVisible(_ incoming: [InstalledApp]) {
        var byPath = Dictionary(apps.map { ($0.containerPath, $0) }, uniquingKeysWith: { first, _ in first })
        for app in incoming { byPath[app.containerPath] = app }
        apps = byPath.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func reload() {
        guard !isResolving, UIApplication.shared.applicationState == .active, WQIntegratedBeginRefresh() else { return }
        pendingRetry?.cancel(); pendingRetry = nil
        let requestToken = UUID()
        reloadToken = requestToken
        WQFilesIdentityResolver.logExperimentalAppGroupStatus()
        log("wqfiles: reload scheduled token=\(requestToken.uuidString) enabled=\(WQFilesIdentityResolver.isEnabled) os=\(AppInfo.osVersion) build=\(AppInfo.osBuild)")
        isLoading = true
        isResolving = true

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            WQIntegratedPrepareRefresh()
            let bundleMetadata = ContainerStore.applicationBundleMetadataCatalog()
            let apiApps = ContainerStore.applyingBundleMetadata(
                to: ContainerStore.installedAppsFromAPI(),
                catalog: bundleMetadata
            )
            if apiApps.isEmpty {
                log("browser: installed-app API unavailable; trying MCM class-2 enumeration...")
            }
            let dynamicIdentifiers = ContainerStore.dynamicAppIdentifiers()
            let mcmApps = ContainerStore.installedAppsFromMCM(
                identifiers: dynamicIdentifiers,
                bundleMetadata: bundleMetadata
            )
            let filesystemApps = ContainerStore.containersFromFilesystem()
            let baseIdentifiedApps = mcmApps + apiApps
            var result = ContainerDiscoveryMerger.merge(
                enumerated: filesystemApps,
                identified: baseIdentifiedApps,
                path: { $0.containerPath }
            )
            log("browser: merged api=\(apiApps.count), MCM=\(mcmApps.count), filesystem=\(filesystemApps.count) -> \(result.count)")
            result.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            let preliminary = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            DispatchQueue.main.async { [self] in
                guard reloadToken == requestToken else {
                    log("wqfiles: async result discarded phase=preliminary token=\(requestToken.uuidString)")
                    return
                }
                mergeVisible(preliminary)
                isLoading = false
            }

            log("wqfiles: provider about_to_run token=\(requestToken.uuidString) filesystem=\(filesystemApps.count)")
            let identities = WQFilesIdentityResolver.resolve(
                containerPaths: filesystemApps.map(\.containerPath)
            )
            log("wqfiles: provider returned token=\(requestToken.uuidString) identities=\(identities.count)")
            var verifiedApps = WQFilesIdentityMerge.verifiedApps(
                identities: identities,
                originalApps: baseIdentifiedApps + filesystemApps
            )
            let originalPathSet = Set(baseIdentifiedApps.map {
                ContainerDiscoveryMerger.canonicalPath($0.containerPath)
            })
            let newPathCount = verifiedApps.filter {
                !originalPathSet.contains(ContainerDiscoveryMerger.canonicalPath($0.containerPath))
            }.count
            log("wqfiles: comparison original=\(baseIdentifiedApps.count), filesystem=\(filesystemApps.count), verified=\(verifiedApps.count), additional=\(newPathCount), unresolved=\(max(0, filesystemApps.count - verifiedApps.count))")

            let identityComparison = WQBundleIdentityCoordinator.evaluate(
                containerPaths: filesystemApps.map(\.containerPath),
                original: identities
            )
            WQBundleIdentityCoordinator.emitDiagnostics(
                identityComparison,
                containerCount: filesystemApps.count
            )
            if !identityComparison.additionalApps.isEmpty {
                verifiedApps = ContainerDiscoveryMerger.merge(
                    enumerated: verifiedApps,
                    identified: identityComparison.additionalApps,
                    path: { $0.containerPath }
                )
            }

            result = ContainerDiscoveryMerger.merge(
                enumerated: result,
                identified: verifiedApps,
                path: { $0.containerPath }
            )
            result.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            DispatchQueue.main.async { [self] in
                guard reloadToken == requestToken else {
                    log("wqfiles: async result discarded phase=provider token=\(requestToken.uuidString)")
                    return
                }
                mergeVisible(result.filter { ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID) })
                isLoading = false
            }

            let launchServicesIdentifiers = ContainerStore.launchServicesStoreIdentifiers()
            let mhaIdentifiers = MHAIdentifierCatalog.identifiers(
                dynamic: dynamicIdentifiers,
                installed: apiApps.map(\.bundleID),
                research: ContainerStore.researchAppIdentifiers,
                custom: bundleMetadata.keys.sorted(),
                launchServices: launchServicesIdentifiers
            )
            log(
                "browser: MHA catalog dynamic=\(dynamicIdentifiers.count), " +
                "installed=\(apiApps.count), research=\(ContainerStore.researchAppIdentifiers.count), " +
                "LaunchServices=\(launchServicesIdentifiers.count) -> \(mhaIdentifiers.count) candidates"
            )
            let mhaApps = ContainerStore.installedAppsFromMHACandidates(
                identifiers: mhaIdentifiers,
                bundleMetadata: bundleMetadata
            ) { discoveredApps in
                var progressiveResult = AppDataCatalogMerger.merge(
                    identified: discoveredApps + baseIdentifiedApps,
                    fallback: [],
                    identifier: { $0.bundleID },
                    path: { $0.containerPath }
                )
                progressiveResult = progressiveResult.filter {
                    ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
                }
                progressiveResult.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            DispatchQueue.main.async { [self] in
                guard reloadToken == requestToken else {
                    log("wqfiles: async result discarded phase=progressive token=\(requestToken.uuidString)")
                    return
                }
                mergeVisible(progressiveResult)
            }
            }

            let allKnownApps = mhaApps + baseIdentifiedApps + verifiedApps
            let identifiedPaths = Set(allKnownApps.map {
                ContainerDiscoveryMerger.canonicalPath($0.containerPath)
            })
            let unmatchedFilesystemApps = filesystemApps.filter {
                !identifiedPaths.contains(
                    ContainerDiscoveryMerger.canonicalPath($0.containerPath)
                )
            }
            let inferredFilesystemApps = ContainerStore.inferUnidentifiedApps(
                in: unmatchedFilesystemApps,
                knownApps: allKnownApps,
                launchServicesIdentifiers: Set(launchServicesIdentifiers)
            ).filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result = AppDataCatalogMerger.merge(
                identified: allKnownApps,
                fallback: inferredFilesystemApps,
                identifier: { $0.bundleID },
                path: { $0.containerPath }
            )
            result = result.filter {
                ContainerPresentationPolicy.shouldShow(bundleID: $0.bundleID)
            }
            result.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }

            DispatchQueue.main.async { [self] in
                guard reloadToken == requestToken else {
                    log("wqfiles: async result discarded phase=final token=\(requestToken.uuidString)")
                    return
                }
                let state = WQIntegratedScanState()["status"] as? String
                if !result.isEmpty && identityComparison.sourceReadable && !wq_full_scan_was_declined()
                    && state != "blocked" && state != "stopped" && !WQIntegratedRefreshHadTransientError() {
                    apps = result
                } else {
                    mergeVisible(result)
                }
                isLoading = false
                isResolving = false
                WQIntegratedEndRefresh()
                log("wqfiles: files displayed=\(result.count)")
                let blocked = (WQIntegratedScanState()["status"] as? String) == "blocked"
                let interrupted = state == "stopped" && UIApplication.shared.applicationState == .active
                scheduleRetry(transient: (WQIntegratedRefreshHadTransientError() && !blocked) || interrupted)
                lastFinished = Date()
            }
        }
    }
}
