import SwiftUI
import Foundation

@MainActor final class VINIStagingStore: ObservableObject {
    @Published private(set) var profile: VINIStagingProfile?
    @Published private(set) var status = "Sin sesión"
    @Published private(set) var verified = false
    @Published private(set) var packages: [VINIStagingPatch] = []
    @Published private(set) var busy = false
    @Published private(set) var packageResult: String?
    private let client = VINIStagingClient()
    private var uptime: TimeInterval = 0
    private var lastRefresh: TimeInterval = -.infinity
    func refresh(licenseKey: String? = nil) async {
        guard !busy else { return }
        if licenseKey == nil && ProcessInfo.processInfo.systemUptime - lastRefresh < 15 { return }
        busy = true; defer { busy = false }
        lastRefresh = ProcessInfo.processInfo.systemUptime
        if licenseKey != nil { profile = nil; verified = false; packages = []; packageResult = nil }
        do {
            let p: VINIStagingProfile
            if let key = licenseKey { p = try await client.login(licenseKey: key) }
            else { p = try await client.profile() }
            profile = p; uptime = ProcessInfo.processInfo.systemUptime
            verified = p.licenseStatus == "active"; status = verified ? "Activa" : "Sin autorización vigente"
            packages = try await client.catalog()
        } catch {
            verified = false
            status = (error as? VINIStagingError)?.message ?? VINIStagingError.invalidResponse.message
            // Keep previous rows visible on connection loss. They never authorize download/Apply.
        }
    }
    func logout() async {
        guard !busy else { return }
        do { try await client.logout(); profile = nil; packages = []; verified = false; status = "Sin sesión"; packageResult = nil }
        catch { verified = false; status = VINIStagingError.keychain.message }
    }
    func download(_ patch: VINIStagingPatch) async {
        guard !busy, verified else { return }
        busy = true; defer { busy = false }
        do { let name = try await client.downloadTestPackage(id: patch.id); packageResult = "Descargado y decodificado: " + name }
        catch { packageResult = (error as? VINIStagingError)?.message ?? "El codec rechazó el paquete" }
    }
    var presentation: VINIDashboardPresentation {
        var remaining: TimeInterval?
        if verified, let p = profile, let expiry = p.licenseExpiresAt,
           let deadline = try? VINIStagingEnvironment.date(expiry), let clock = try? VINIStagingEnvironment.date(p.serverTime) {
            remaining = max(0, deadline.timeIntervalSince(clock) - max(0, ProcessInfo.processInfo.systemUptime - uptime))
        }
        let active = verified && (remaining == nil || remaining! > 0)
        return VINIDashboardPresentation(isPreview: profile == nil,
            license: VINILicensePresentation(userName: profile?.username ?? "—", plan: profile?.plan.uppercased() ?? "—",
                isPreview: profile == nil, isVerified: active, verifiedRemainingSeconds: remaining,
                status: verified && !active ? "Licencia expirada" : status),
            targets: VINIDashboardPresentation.preview.targets, initialPreviewSelection: [])
    }
}

struct VINIStagingDashboard: View {
    @StateObject private var store = VINIStagingStore()
    @State private var account = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VINIDashboardView(presentation: store.presentation, openAccount: { account = true })
        }
        .task { await store.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await store.refresh() } }
        }
        .sheet(isPresented: $account) { VINIStagingAccountView(store: store) }
    }
}

// Account/catalog presentation is reached through the existing license card;
// no dashboard cards, categories, switches, fonts or spacing are replaced.
struct VINIStagingAccountView: View {
    @ObservedObject var store: VINIStagingStore
    @State private var licenseKey = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta · staging") {
                    Text(store.status)
                    SecureField("Clave de licencia de prueba", text: $licenseKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Iniciar sesión") {
                        let key = licenseKey; licenseKey = ""
                        Task { await store.refresh(licenseKey: key) }
                    }.disabled(store.busy || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Comprobar sesión") { Task { await store.refresh() } }.disabled(store.busy)
                    Button("Cerrar sesión") { Task { await store.logout() } }.disabled(store.busy)
                }
                Section("Paquetes autorizados") {
                    ForEach(store.packages) { patch in
                        VStack(alignment: .leading) {
                            Text(patch.name)
                            if let description = patch.description, !description.isEmpty { Text(description).font(.caption) }
                            if patch.id == VINIStagingEnvironment.fixtureID {
                                Button("Descargar y verificar paquete de prueba") { Task { await store.download(patch) } }
                                    .disabled(store.busy || !store.verified)
                            } else { Text("Sin hash de referencia de prueba").font(.caption) }
                        }
                    }
                    if let result = store.packageResult { Text(result).font(.caption) }
                }
            }
            .navigationTitle("Cuenta VINI")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }
}
