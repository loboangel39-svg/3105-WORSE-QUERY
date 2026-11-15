import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage("interface.appearance") private var appearance = "dark"
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.spanish.rawValue
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("3105").font(.headline)
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(language.text("appearance.title")) {
                    Picker(language.text("appearance.title"), selection: $appearance) {
                        Text(language.text("appearance.dark")).tag("dark")
                        Text(language.text("appearance.light")).tag("light")
                        Text(language.text("appearance.system")).tag("system")
                    }.pickerStyle(.segmented)
                }
                Section(language.text("settings.language")) {
                    Picker(language.text("settings.language"), selection: $languageCode) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: languageCode) { code in UserDefaults.standard.set(code, forKey: "WQLanguage") }
                }

                Section {
                    Toggle(isOn: $cleanerEnabled) {
                        Label(language.text("tab.cleaner"), systemImage: "sparkles")
                    }
                    Toggle(isOn: $developerModeEnabled) {
                        Label(
                            language.text("settings.developer_mode"),
                            systemImage: "hammer.fill"
                        )
                    }
                } header: {
                    Text(language.text("dashboard.features"))
                } footer: {
                    Text(language.text("settings.developer_mode_footer"))
                }

                if WallpaperFeatureSupportPolicy.isSupported(
                    major: AppInfo.versionTuple.major
                ) {
                    Section {
                        NavigationLink {
                            WallpaperResetSettingsView()
                        } label: {
                            Label(
                                language.text("wallpaper.reset"),
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                    } header: {
                        Text(language.text("tab.wallpapers"))
                    } footer: {
                        Text(language.text("wallpaper.reset_settings_footer"))
                    }
                }

                if #available(iOS 26.0, *) {
                    Section("WQFiles") {
                        NavigationLink(language.text("settings.wqfiles_tools")) {
                            WQFilesIntegratedView().ignoresSafeArea()
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                }

                Section(language.text("common.device")) {
                    LabeledContent(language.text("dashboard.hardware_model"), value: AppInfo.displayMachineName)
                    LabeledContent(language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                }

                Section {
                    HStack {
                        Text(language.text("settings.current_version"))
                        Spacer()
                        Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                        .foregroundStyle(appState.isSupported ? Color.green : Color.red)
                    }
                    LabeledContent("iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
                    LabeledContent("iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
                    LabeledContent("iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("iOS 27.0")
                            .font(.body)
                        ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                            Text(versionLabel(version))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text(language.text("settings.verified_versions"))
                } footer: {
                    Text(language.text("settings.supported_versions_footer"))
                }

                Section(language.text("settings.open_source_licenses")) {
                    NavigationLink(language.text("settings.open_source_licenses")) {
                        ScrollView { Text(openSourceLicenses).font(.caption).textSelection(.enabled).padding() }
                            .navigationTitle(language.text("settings.open_source_licenses"))
                    }
                }
            }
            .controllerSurface()
            .tint(AppTheme.accent)
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(language.text("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var openSourceLicenses: String {
        guard let bundleURL = Bundle.main.url(forResource: "WQFilesResources", withExtension: "bundle"),
              let bundle = Bundle(url: bundleURL), let url = bundle.url(forResource: "OPEN_SOURCE_LICENSES", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "GPL-3.0-or-later" }
        return text
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
        if let publicBeta = version.publicBeta {
            return language.text(
                "settings.developer_public_beta_build",
                Int64(version.beta),
                Int64(publicBeta),
                version.build
            )
        }
        return language.text(
            "settings.developer_beta_build",
            Int64(version.beta),
            version.build
        )
    }

}

private struct WQFilesIntegratedView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        WQIntegratedMakeViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
