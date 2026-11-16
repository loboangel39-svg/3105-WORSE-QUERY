import SwiftUI
import Foundation

struct VINIAuthenticationRoot: View {
    @StateObject private var store = VINIProductionStore()
    @Environment(\.scenePhase) private var scenePhase
    var onAuthorized: () -> Void
    var onImport: (URL) -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if store.phase == .authorized && store.authorizationDeadline > ProcessInfo.processInfo.systemUptime {
                ContentView()
            } else if store.phase == .checking && store.hasStoredIdentity == true {
                VINIConnectingView()
            } else { VINILicenseLogin(store: store) }
        }
        .task { await store.bootstrap() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await store.refresh(force: true) } }
        }
        .onChange(of: store.phase) { phase in if phase == .authorized { onAuthorized() } }
        .task(id: store.authorizationDeadline) {
            let deadline = store.authorizationDeadline
            guard deadline > 0 else { return }
            let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime)
            do { try await Task.sleep(nanoseconds: UInt64(min(delay, 86_400) * 1_000_000_000)) }
            catch { return }
            if store.phase == .authorized { await store.refresh(force: true) }
        }
        .onOpenURL { url in
            if store.phase == .authorized && store.authorizationDeadline > ProcessInfo.processInfo.systemUptime { onImport(url) }
        }
    }
}

struct VINIConnectingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressView().tint(.white)
                Text("Conectando con el servidor").foregroundStyle(.white)
            }
        }.preferredColorScheme(.dark).accessibilityIdentifier("vini-connecting")
    }
}

struct VINILicenseLogin: View {
    @ObservedObject var store: VINIProductionStore
    @State private var license = ""
    private var busy: Bool { store.busy || store.phase == .checking || store.phase == .validating }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 44)
                    Text("ϟ").font(AppTheme.sans(43).weight(.light)).foregroundStyle(Color(red: 0, green: 0.82, blue: 1))
                        .frame(width: 72, height: 72)
                        .background(Color(red: 0.04, green: 0.08, blue: 0.12), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.accent.opacity(0.6), lineWidth: 0.8))
                        .shadow(color: AppTheme.accent.opacity(0.16), radius: 16)
                    HStack(spacing: 9) {
                        Text("VINI").font(AppTheme.sans(28).weight(.heavy)).foregroundStyle(.white)
                        Text("VINI" + (version.isEmpty ? "" : " · v" + version)).font(AppTheme.mono(9).weight(.bold)).foregroundStyle(AppTheme.accent)
                            .padding(6).background(AppTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
                    }.padding(.top, 20)
                    Text("ENVIRONMENT AUTHENTICATION").font(AppTheme.mono(9).weight(.semibold))
                        .tracking(1).foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.77)).padding(.top, 12)
                    Spacer(minLength: 26)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("LICENSE KEY").font(AppTheme.mono(10).weight(.bold)).tracking(0.6).foregroundStyle(AppTheme.accent)
                        HStack(spacing: 10) {
                            Image(systemName: "diamond.fill").font(.system(size: 9)).foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.77))
                            SecureField("VINI-XXXX-XXXX-XXXX", text: $license)
                                .font(AppTheme.mono(11)).foregroundStyle(.white)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .submitLabel(.go).onSubmit { authenticate() }
                        }.padding(.horizontal, 14).frame(height: 46)
                            .background(Color(red: 0.025, green: 0.035, blue: 0.05), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                        if store.phase != .login || store.status != "Sin sesión" {
                            Text(busy ? "Validando autorización…" : store.status)
                                .font(AppTheme.mono(10)).foregroundStyle(.secondary).accessibilityIdentifier("login-status")
                        }
                        Button(action: authenticate) {
                            HStack(spacing: 10) { Image(systemName: "arrow.right"); Text("AUTHENTICATE") }
                                .font(AppTheme.mono(12).weight(.bold)).foregroundStyle(.black)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 13))
                                .shadow(color: AppTheme.accent.opacity(0.22), radius: 10, y: 4)
                        }.buttonStyle(.plain).disabled(busy || (license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.phase != .blocked))
                    }.padding(18).background(Color(red: 0.05, green: 0.065, blue: 0.09), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    Spacer(minLength: 30)
                    HStack {
                        Circle().fill(store.phase == .blocked ? .gray : AppTheme.accent).frame(width: 3, height: 3)
                        Text(store.phase == .blocked ? "Sin conexión verificada" : busy ? "Comprobando servidor" : "Sesión no autorizada")
                            .font(AppTheme.sans(9)).foregroundStyle(.secondary)
                        Spacer()
                        Text("CLOUDFLARE · VINI").font(AppTheme.mono(8).weight(.bold)).foregroundStyle(AppTheme.accent)
                            .padding(6).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }.padding(.bottom, 22)
                }.padding(.horizontal, 24).frame(maxWidth: 430).frame(minHeight: max(560, geometry.size.height))
                    .frame(maxWidth: .infinity)
            }.scrollDismissesKeyboard(.interactively)
        }.background {
            ZStack {
                Color(red: 0.023, green: 0.035, blue: 0.05)
                RadialGradient(colors: [AppTheme.accent.opacity(0.13), .clear], center: .top, startRadius: 0, endRadius: 360)
            }.ignoresSafeArea()
        }.preferredColorScheme(.dark).accessibilityIdentifier("vini-license-login")
    }
    private func authenticate() {
        guard !busy else { return }
        if license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if store.phase == .blocked { Task { await store.refresh(force: true) } }
            return
        }
        let key = license; license = ""
        Task { await store.refresh(licenseKey: key, force: true) }
    }
}
