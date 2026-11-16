import SwiftUI
import Foundation

// Stable presentation IDs are not package assignments or authenticated server records.
enum VINICategory: String, CaseIterable, Identifiable {
    case combat, visuals, offsets
    var id: String { rawValue }
    var title: String {
        switch self { case .combat: return "Combat"; case .visuals: return "Visuals"; case .offsets: return "Offsets" }
    }
}
enum VINITargetAvailability: Equatable { case preview, available, unavailable }
enum VINIPatchState: Equatable { case unknown, inactive, active }
struct VINITargetPresentation: Identifiable {
    let targetID: String
    let packageID: String?
    let categoryID: String
    let title: String
    let patchDescription: String?
    let symbol: String
    let availability: VINITargetAvailability
    let patchState: VINIPatchState
    var id: String { targetID }
}
struct VINILicensePresentation {
    let userName: String
    let plan: String
    let isPreview: Bool
    let isVerified: Bool
    let verifiedRemainingSeconds: TimeInterval?
    var status: String = "Sin sesión"
}
struct VINIDashboardPresentation {
    let isPreview: Bool
    let license: VINILicensePresentation
    let targets: [VINITargetPresentation]
    let initialPreviewSelection: Set<String>
    let onToggle: ((String, Bool) -> Void)?

    static let preview: VINIDashboardPresentation = {
        func target(_ id: String, _ category: VINICategory, _ title: String, _ symbol: String) -> VINITargetPresentation {
            VINITargetPresentation(targetID: "vini." + id, packageID: nil, categoryID: category.rawValue,
                title: title, patchDescription: nil, symbol: symbol,
                availability: .unavailable, patchState: .unknown)
        }
        return VINIDashboardPresentation(isPreview: true,
            license: VINILicensePresentation(userName: "—", plan: "—", isPreview: true,
                isVerified: false, verifiedRemainingSeconds: nil),
            targets: [
                target("aim_drag", .combat, "Aim Drag Pro", "bolt"),
                target("aim_head", .combat, "Aimbot Cabeza", "scope"),
                target("aim_neck", .combat, "Aimbot Cuello", "shield"),
                target("aim_chest", .combat, "Aimbot Pecho", "person"),
                target("direct_hit", .combat, "Balas Mágicas / Direct Hit", "flask"),
                target("wireframe", .visuals, "Chams Wireframe GL", "eye"),
                target("esp_box", .visuals, "ESP Box 2D", "square.dashed"),
                target("radar", .visuals, "Distance Radar", "map"),
                target("integrity", .offsets, "Bypass Integrity Check", "lock"),
                target("memory", .offsets, "Memory Allocation Fix", "memorychip")
            ], initialPreviewSelection: [], onToggle: nil)
    }()
}

struct VINIDashboardView: View {
    let presentation: VINIDashboardPresentation
    let openAccount: () -> Void
    let onExit: () -> Void
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("interface.appearance") private var appearance = "dark"
    @State private var category: VINICategory = .combat

    init(presentation: VINIDashboardPresentation = .preview, openAccount: @escaping () -> Void = {}, onExit: @escaping () -> Void = {}) {
        self.presentation = presentation
        self.openAccount = openAccount
        self.onExit = onExit
        AppTheme.configure()
    }
    private var visibleTargets: [VINITargetPresentation] {
        presentation.targets.filter { $0.categoryID == category.rawValue }
    }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) { header; sectionHeading; targets; footer }
                }
            } else {
                VStack(spacing: 0) {
                    header
                    sectionHeading
                    ScrollView { targets }
                    footer
                }
            }
        }
        .frame(maxWidth: 600, maxHeight: .infinity)
        .background(ControllerCanvas())
        .tint(AppTheme.accent)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "light" ? .light : .dark)
        .accessibilityIdentifier("vini-dashboard")
    }
    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VINIHeaderView(isPreview: presentation.isPreview, status: presentation.license.status)
                Button(action: onExit) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.accent.opacity(0.30), lineWidth: 0.75))
                }.buttonStyle(.plain).accessibilityLabel("Salir")
            }
            VINILicenseCard(license: presentation.license)
            VINICategorySelector(selection: $category)
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }
    private var sectionHeading: some View {
        HStack {
            Text(category.title.uppercased()).foregroundStyle(AppTheme.accent)
            Spacer()
            Text(presentation.isPreview ? language.text("vini.demo_controls") : presentation.license.status).foregroundStyle(.secondary)
        }.font(AppTheme.mono(10).weight(.semibold)).tracking(0.7)
         .padding(.horizontal, 20).padding(.bottom, 6)
    }
    private var targets: some View {
        LazyVStack(spacing: 10) {
            ForEach(visibleTargets) { target in
                VINITargetCard(target: target, isOn: Binding(
                    get: { target.patchState == .active },
                    // No authoritative Worker assignment exists yet. A display
                    // model or imported file cannot authorize a mutation.
                     set: { value in presentation.onToggle?(target.targetID, value) }))
            }
        }.padding(.horizontal, 20).padding(.vertical, 4)
         .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: category)
    }
    private var footer: some View {
        VINISystemInfoCard().padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
    }
}

struct VINIHeaderView: View {
    var isPreview = true
    var status = "Sin sesión"
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var enginePresentation: VINIEnginePresentationStore
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                Text("VINI").font(AppTheme.sans(24, relativeTo: .title2).weight(.heavy)).tracking(1.4)
                Text(isPreview ? "PREVIEW" + (version.isEmpty ? "" : " · v" + version) : "VINI" + (version.isEmpty ? "" : " · v" + version))
                    .font(AppTheme.mono(10).weight(.bold)).foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.accent.opacity(0.35), lineWidth: 0.75))
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Circle().fill(enginePresentation.verifiedProvider != nil ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6).accessibilityHidden(true)
                Text(isPreview ? language.text("vini.preview_mode") : enginePresentation.displayText(appState: appState))
                    .font(AppTheme.sans(11, relativeTo: .caption))
                    .foregroundStyle(enginePresentation.verifiedProvider != nil ? Color.green : Color.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VINILicenseCard: View {
    let license: VINILicensePresentation
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var typeSize
    private var remainingText: String {
        if license.isVerified && license.verifiedRemainingSeconds == nil { return license.status + " · Permanente" }
        guard license.isVerified, let seconds = license.verifiedRemainingSeconds, seconds.isFinite, seconds >= 0 else {
            return license.status
        }
        // Display a supplied verified duration; this view does not run a timer or obtain a license.
        let minutes = Int64(min(seconds / 60, Double(Int64.max / 2)))
        return license.status + " · " + String(format: "%lldd %02lldh %02lldm", minutes / 1440, (minutes % 1440) / 60, minutes % 60)
    }
    private var identity: some View {
        HStack(spacing: 8) {
            Text("V").font(AppTheme.sans(12).weight(.bold)).foregroundStyle(AppTheme.accent)
                .frame(width: 26, height: 26).background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            Text(license.userName).font(AppTheme.sans(12, relativeTo: .subheadline).weight(.semibold))
            Text(license.plan).font(AppTheme.mono(9).weight(.bold)).foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 5).padding(.vertical, 3)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        }
    }
    private var remaining: some View {
        Label(remainingText, systemImage: "clock")
            .font(AppTheme.mono(10)).foregroundStyle(AppTheme.accent)
            .accessibilityLabel(language.text("vini.license_time") + ": " + remainingText)
    }
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { identity; remaining }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 10) { identity; Spacer(minLength: 0); remaining }
            }
        }.padding(.horizontal, 12).padding(.vertical, 11)
         .background(AppTheme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
         .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border.opacity(0.7), lineWidth: 0.75))
         .accessibilityIdentifier("vini-license-preview")
    }
}

struct VINICategorySelector: View {
    @Binding var selection: VINICategory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(VINICategory.allCases) { category in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { selection = category }
                } label: {
                    Text(category.title).font(AppTheme.sans(12, relativeTo: .subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selection == category ? AppTheme.accent : Color.secondary)
                        .background(selection == category ? AppTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selection == category ? AppTheme.accent.opacity(0.4) : .clear, lineWidth: 0.75))
                }.buttonStyle(.plain).accessibilityIdentifier("vini-category-" + category.rawValue)
                 .accessibilityAddTraits(selection == category ? .isSelected : [])
            }
        }.padding(4).background(AppTheme.consoleBackground.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
         .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.border.opacity(0.65), lineWidth: 0.75))
    }
}

struct VINITargetCard: View {
    let target: VINITargetPresentation
    @Binding var isOn: Bool
    @Environment(\.appLanguage) private var language
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: target.symbol).font(.system(size: 20, weight: .medium))
                .foregroundStyle(isOn ? AppTheme.accent : Color.secondary)
                .frame(width: 40, height: 40)
                .background(isOn ? AppTheme.accent.opacity(0.10) : AppTheme.border.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn ? AppTheme.accent.opacity(0.35) : AppTheme.border.opacity(0.65), lineWidth: 0.75))
                .shadow(color: isOn ? AppTheme.accent.opacity(0.16) : .clear, radius: 7)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(target.title).font(AppTheme.sans(14, relativeTo: .subheadline).weight(.semibold))
                Text(target.patchDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                     ? target.patchDescription! : language.text("vini.no_patch"))
                    .font(AppTheme.sans(11, relativeTo: .caption))
                    .foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            Toggle(target.title, isOn: $isOn).labelsHidden().tint(AppTheme.accent)
                .frame(width: 52).frame(minHeight: 44)
                .disabled(target.availability != .available)
                .accessibilityIdentifier("vini-toggle-" + target.targetID)
                .accessibilityLabel(target.title)
                .accessibilityHint(language.text("vini.toggle_hint"))
                .accessibilityValue(language.text(isOn ? "vini.preview_on" : "vini.preview_off"))
                .shadow(color: isOn ? AppTheme.accent.opacity(0.3) : .clear, radius: 7)
        }.padding(12).frame(minHeight: 72)
         .background(AppTheme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
         .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border.opacity(0.65), lineWidth: 0.75))
         .accessibilityElement(children: .contain)
    }
}

struct VINISystemInfoCard: View {
    @Environment(\.appLanguage) private var language
    private var compatibility: VINICompatibility {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return VINICompatibilityResolver.resolve(major: version.majorVersion,
            minor: version.minorVersion, patch: version.patchVersion, build: AppInfo.osBuild)
    }
    private var architecture: String {
#if arch(arm64)
        return "arm64"
#else
        return language.text("vini.unavailable")
#endif
    }
    var body: some View {
        VStack(spacing: 8) {
            row(language.text("vini.device"), AppInfo.displayMachineName)
            row("iOS", AppInfo.osVersion + " (" + AppInfo.osBuild + ")")
            row(language.text("vini.status"), language.text(compatibility.documented ? "vini.compatible" : "vini.not_verified"), accent: true)
            row(language.text("vini.architecture"), architecture)
        }.font(AppTheme.mono(10)).padding(14)
         .background(AppTheme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
         .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border.opacity(0.65), lineWidth: 0.75))
    }
    private func row(_ name: String, _ value: String, accent: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(name.uppercased()).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).foregroundStyle(accent ? AppTheme.accent : Color.primary).multilineTextAlignment(.trailing)
        }
    }
}
