import SwiftUI
import Foundation

enum VINIAuthenticationPhase: Equatable { case checking, login, validating, authorized, blocked }

@MainActor final class VINIProductionStore: ObservableObject {
    @Published private(set) var phase: VINIAuthenticationPhase = .checking
    @Published private(set) var hasStoredIdentity: Bool?
    @Published private(set) var authorizationDeadline: TimeInterval = 0
    @Published private(set) var fixtureState = "Sin ensayo"
    @Published private(set) var preparedFixture = false
    @Published private(set) var fixtureCanApply = false
    @Published private(set) var fixtureCanRestore = false
    @Published private(set) var fixtureEvidence: URL?
    private let fixture = VINIIsolatedFixture()
    @Published private(set) var profile: VINIStagingProfile?
    @Published private(set) var status = "Sin sesión"
    @Published private(set) var verified = false
    @Published private(set) var packages: [VINIStagingPatch] = []
    @Published private(set) var preparedPackages: [VINIRemotePreparedPackage] = []
    @Published private(set) var busy = false
    @Published private(set) var packageResult: String?
    private let client = VINIStagingClient()
    private var uptime: TimeInterval = 0
    private var lastRefresh: TimeInterval = -.infinity
    func bootstrap() async {
        hasStoredIdentity = (try? await client.hasStoredIdentity()) ?? false
        await refresh(force: true)
    }
    private func finishOperation() {
        busy = false
        if phase == .authorized && authorizationDeadline <= ProcessInfo.processInfo.systemUptime {
            Task { await self.refresh(force: true) }
        }
    }
    private func checkAuthorizationAfterFailure(_ error: Error) async {
        guard let cause = error as? VINIStagingError else { return }
        guard [.signedOut, .invalidLicense, .blockedLicense, .paused, .denied, .expired, .offline, .keychain].contains(cause) else { return }
        do {
            let p = try await client.profile()
            let lifetime = try await client.authorizationLifetime(p)
            profile = p; uptime = ProcessInfo.processInfo.systemUptime
            authorizationDeadline = uptime + lifetime
        } catch {
            verified = false; authorizationDeadline = 0
            phase = (error as? VINIStagingError) == .offline ? .blocked : .login
            status = (error as? VINIStagingError)?.message ?? "Autorización sin verificar"
        }
    }
    func refresh(licenseKey: String? = nil, force: Bool = false) async {
        guard !busy else { return }
        if !force && licenseKey == nil && ProcessInfo.processInfo.systemUptime - lastRefresh < 15 { return }
        busy = true; defer { finishOperation() }
        lastRefresh = ProcessInfo.processInfo.systemUptime
        phase = licenseKey == nil ? .checking : .validating
        if licenseKey != nil { preparedFixture = false; profile = nil; verified = false; packages = []; packageResult = nil }
        do {
            let p: VINIStagingProfile
            if let key = licenseKey { p = try await client.login(licenseKey: key) }
            else { p = try await client.profile() }
            let lifetime = try await client.authorizationLifetime(p)
            profile = p; uptime = ProcessInfo.processInfo.systemUptime
            authorizationDeadline = uptime + lifetime
            phase = .authorized
            verified = p.licenseStatus == "active"; status = verified ? "Activa" : "Sin autorización vigente"
            do {
                packages = try await client.catalog()
                let authorized = packages
                let prepared = try await VINIRemotePackageCoordinator(client: client).prepareAuthorizedPackages()
                preparedPackages = prepared
            } catch { packageResult = "Catálogo temporalmente no disponible" }
            await inspectFixture()
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
        do { try await client.logout(); preparedFixture = false; preparedPackages = []; profile = nil; packages = []; verified = false; phase = .login; authorizationDeadline = 0; status = "Sin sesión"; packageResult = nil }
        catch { verified = false; phase = .blocked; status = VINIStagingError.keychain.message }
    }
    func download(_ patch: VINIStagingPatch) async {
        guard !busy, verified else { return }
        busy = true; defer { finishOperation() }
        do {
            let p = try await client.profile(); _ = try await client.authorizationLifetime(p)
            let name = try await client.downloadTestPackage(id: patch.id)
            packageResult = "Descargado y decodificado: " + name; preparedFixture = true; await inspectFixture()
        }
        catch { preparedFixture = false; packageResult = (error as? VINIStagingError)?.message ?? "El codec rechazó el paquete"; await checkAuthorizationAfterFailure(error) }
    }
    private func inspectFixture() async {
        do {
            let (state, canApply, canRestore, evidence) = try await fixture.inspection()
            fixtureState = state; fixtureCanApply = canApply; fixtureCanRestore = canRestore; fixtureEvidence = evidence
        } catch { fixtureState = "Recuperación requerida"; fixtureCanApply = false; fixtureCanRestore = false; fixtureEvidence = nil }
    }
    func applyFixture() async {
        guard !busy, phase == .authorized, preparedFixture, fixtureCanApply else { return }
        busy = true; defer { finishOperation() }
        do {
            let p = try await client.profile(); _ = try await client.authorizationLifetime(p)
            let bytes = try await client.verifiedTestBytes(id: VINIStagingEnvironment.fixtureID)
            let finalProfile = try await client.profile(); _ = try await client.authorizationLifetime(finalProfile)
            fixtureState = try await fixture.apply(bytes: bytes)
            await inspectFixture()
        } catch { preparedFixture = false; await inspectFixture(); packageResult = "Apply no confirmado; revisar receipt del ensayo"; await checkAuthorizationAfterFailure(error) }
    }
    func restoreFixture() async {
        guard !busy, fixtureCanRestore else { return }; busy = true; defer { busy = false }
        do { fixtureState = try await fixture.restore(); await inspectFixture() }
        catch { await inspectFixture(); packageResult = "Restore no confirmado; recuperación conservada" }
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
            targets: preparedPresentations, initialPreviewSelection: [])
    }
    private var preparedPresentations: [VINITargetPresentation] {
        guard profile != nil else { return VINIDashboardPresentation.preview.targets }
        return VINIProductionTargetModel.resolve(catalog: packages, prepared: preparedPackages).map { target in
            let category = target.category == "visuals" ? VINICategory.visuals : target.category == "offsets" ? VINICategory.offsets : VINICategory.combat
            let symbol = category == .visuals ? "eye" : category == .offsets ? "slider.horizontal.3" : "bolt"
            return VINITargetPresentation(targetID: target.targetID, packageID: target.packageID.uuidString,
                categoryID: category.rawValue, title: target.name, patchDescription: target.description,
                symbol: symbol, availability: .available, patchState: .unknown)
        }
    }
}

struct VINIProductionDashboard: View {
    @ObservedObject var store: VINIProductionStore
    @State private var account = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            VINIDashboardView(presentation: store.presentation, onExit: { Task { await store.logout() } })
        }
        .sheet(isPresented: $account) { VINIStagingAccountView(store: store) }
    }
}

// Account/catalog presentation is reached through the existing license card;
// no dashboard cards, categories, switches, fonts or spacing are replaced.
struct VINIStagingAccountView: View {
    @ObservedObject var store: VINIProductionStore
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
                        .disabled(store.busy || !store.verified || !store.preparedFixture || !store.fixtureCanApply || !store.packages.contains { $0.id == VINIStagingEnvironment.fixtureID })
                    Button("Restore del fixture") { Task { await store.restoreFixture() } }.disabled(store.busy || !store.fixtureCanRestore)
                    if let evidence = store.fixtureEvidence { ShareLink("Exportar evidencia del fixture", item: evidence) }
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
