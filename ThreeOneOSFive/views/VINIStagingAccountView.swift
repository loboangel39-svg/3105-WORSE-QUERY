import SwiftUI
import Foundation

enum VINIAuthenticationPhase: Equatable { case checking, login, validating, authorized, blocked }

@MainActor final class VINIStagingStore: ObservableObject {
    @Published private(set) var phase: VINIAuthenticationPhase = .checking
    @Published private(set) var authorizationDeadline: TimeInterval = 0
    @Published private(set) var fixtureState = "Sin ensayo"
    private let fixture = VINIIsolatedFixture()
    @Published private(set) var profile: VINIStagingProfile?
    @Published private(set) var status = "Sin sesión"
    @Published private(set) var verified = false
    @Published private(set) var packages: [VINIStagingPatch] = []
    @Published private(set) var busy = false
    @Published private(set) var packageResult: String?
    private let client = VINIStagingClient()
    private var uptime: TimeInterval = 0
    private var lastRefresh: TimeInterval = -.infinity
    func refresh(licenseKey: String? = nil, force: Bool = false) async {
        guard !busy else { return }
        if !force && licenseKey == nil && ProcessInfo.processInfo.systemUptime - lastRefresh < 15 { return }
        busy = true; defer { busy = false }
        lastRefresh = ProcessInfo.processInfo.systemUptime
        phase = licenseKey == nil ? .checking : .validating
        if licenseKey != nil { profile = nil; verified = false; packages = []; packageResult = nil }
        do {
            let p: VINIStagingProfile
            if let key = licenseKey { p = try await client.login(licenseKey: key) }
            else { p = try await client.profile() }
            let lifetime = try await client.authorizationLifetime(p)
            profile = p; uptime = ProcessInfo.processInfo.systemUptime
            authorizationDeadline = uptime + lifetime
            phase = .authorized
            verified = p.licenseStatus == "active"; status = verified ? "Activa" : "Sin autorización vigente"
            do { packages = try await client.catalog() }
            catch { packageResult = "Catálogo temporalmente no disponible" }
        } catch {
            verified = false
            phase = (error as? VINIStagingError) == .offline ? .blocked : .login
            authorizationDeadline = 0
            status = (error as? VINIStagingError)?.message ?? VINIStagingError.invalidResponse.message
            // Keep previous rows visible on connection loss. They never authorize download/Apply.
        }
    }
    func logout() async {
        guard !busy else { return }
        do { try await client.logout(); profile = nil; packages = []; verified = false; phase = .login; authorizationDeadline = 0; status = "Sin sesión"; packageResult = nil }
        catch { verified = false; phase = .blocked; status = VINIStagingError.keychain.message }
    }
    func download(_ patch: VINIStagingPatch) async {
        guard !busy, verified else { return }
        busy = true; defer { busy = false }
        do { let name = try await client.downloadTestPackage(id: patch.id); packageResult = "Descargado y decodificado: " + name }
        catch { packageResult = (error as? VINIStagingError)?.message ?? "El codec rechazó el paquete" }
    }
    func applyFixture() async {
        guard !busy, phase == .authorized else { return }
        busy = true; defer { busy = false }
        do {
            let p = try await client.profile(); _ = try await client.authorizationLifetime(p)
            let bytes = try await client.verifiedTestBytes(id: VINIStagingEnvironment.fixtureID)
            fixtureState = try await fixture.apply(bytes: bytes)
        } catch { fixtureState = "Apply no confirmado; revisar receipt del ensayo" }
    }
    func restoreFixture() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { fixtureState = try await fixture.restore() }
        catch { fixtureState = "Restore no confirmado; recuperación conservada" }
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
    @ObservedObject var store: VINIStagingStore
    @State private var account = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VINIDashboardView(presentation: store.presentation, openAccount: { account = true })
        }
        .sheet(isPresented: $account) { VINIStagingAccountView(store: store) }
    }
}

// Account/catalog presentation is reached through the existing license card;
// no dashboard cards, categories, switches, fonts or spacing are replaced.
struct VINIStagingAccountView: View {
    @ObservedObject var store: VINIStagingStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Cuenta · staging") {
                    Text(store.status)
                    Button("Comprobar sesión") { Task { await store.refresh() } }.disabled(store.busy)
                    Button("Cerrar sesión") { Task { await store.logout() } }.disabled(store.busy)
                }
                Section("Ensayo aislado · archivos propios") {
                    Text(store.fixtureState).font(.caption)
                    Button("Apply del fixture autorizado") { Task { await store.applyFixture() } }
                        .disabled(store.busy || !store.verified || !store.packages.contains { $0.id == VINIStagingEnvironment.fixtureID })
                    Button("Restore del fixture") { Task { await store.restoreFixture() } }.disabled(store.busy)
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
