import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: VINIProductionStore
    @EnvironmentObject private var enginePresentation: VINIEnginePresentationStore

    var body: some View {
        Form {
                Section {
                    LabeledContent("Usuario", value: authStore.profile?.username ?? "—")
                    LabeledContent("Plan", value: plan)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        LabeledContent("Tiempo restante", value: authStore.licenseCountdown)
                    }
                    LabeledContent("Proveedor", value: enginePresentation.displayText(appState: appState))
                        .foregroundStyle(AppTheme.accent)
                    Button("Cerrar sesión", role: .destructive) {
                        Task { await authStore.logout() }
                    }
                    .disabled(authStore.busy)
                }
                .controllerRow()
            }
        .listStyle(.plain)
        .controllerSurface()
        .tint(AppTheme.accent)
    }

    private var plan: String {
        guard let value = authStore.profile?.plan.uppercased(), value == "PRO" || value == "BASIC" else {
            return "—"
        }
        return value
    }
}
