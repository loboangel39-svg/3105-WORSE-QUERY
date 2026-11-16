import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: VINIProductionStore
    @EnvironmentObject private var enginePresentation: VINIEnginePresentationStore
    @AppStorage("interface.appearance") private var appearance = "dark"
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.spanish.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo()

                        VStack(alignment: .leading, spacing: 3) {
                            Text("VINI 2.0").font(.headline)
                            Text(language.text("common.version", appVersion))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .controllerRow()

                Section("Licencia") {
                    LabeledContent("Estado", value: authStore.status)
                    LabeledContent("Usuario", value: authStore.profile?.username ?? "—")
                    LabeledContent("Plan", value: authStore.profile?.plan.uppercased() ?? "—")
                    LabeledContent("Expiración", value: formattedDate(authStore.profile?.licenseExpiresAt))
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent("Tiempo restante", value: authStore.licenseCountdown)
                    }
                    Button("Comprobar autorización") { Task { await authStore.refresh(force: true) } }
                    Button("Cerrar sesión", role: .destructive) { Task { await authStore.logout() } }
                }
                .controllerRow()

                Section("Dispositivo y acceso") {
                    LabeledContent("Dispositivo", value: AppInfo.displayMachineName)
                    LabeledContent("iOS", value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    LabeledContent("Proveedor", value: enginePresentation.displayText(appState: appState))
                }
                .controllerRow()

                Section(language.text("appearance.title")) {
                    Picker(language.text("appearance.title"), selection: $appearance) {
                        Text(language.text("appearance.dark")).tag("dark")
                        Text(language.text("appearance.light")).tag("light")
                        Text(language.text("appearance.system")).tag("system")
                    }.pickerStyle(.segmented)
                }
                .controllerRow()
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
                .controllerRow()

                Section(language.text("settings.open_source_licenses")) {
                    NavigationLink(language.text("settings.open_source_licenses")) {
                        ScrollView { Text(openSourceLicenses).font(.caption).textSelection(.enabled).padding() }
                            .navigationTitle(language.text("settings.open_source_licenses"))
                    }
                }
                .controllerRow()
            }
            .controllerSurface()
            .tint(AppTheme.accent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formattedDate(_ value: String?) -> String {
        guard let value, let date = try? VINIStagingEnvironment.date(value) else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
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
