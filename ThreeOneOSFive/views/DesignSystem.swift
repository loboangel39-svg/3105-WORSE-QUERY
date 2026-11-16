import SwiftUI
import CoreText

enum AppTheme {
    static func color(_ dark: UInt32, _ light: UInt32) -> Color { Color(uiColor: uiColor(dark, light)) }
    static func uiColor(_ dark: UInt32, _ light: UInt32) -> UIColor {
        UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
    static let accent = color(0x00D2FF, 0x006A88)
    static let pageBackground = color(0x080B13, 0xF2F7FB)
    static let consoleBackground = color(0x101522, 0xFFFFFF)
    static let card = color(0x101522, 0xFFFFFF)
    static let border = color(0x293246, 0xCCD9E3)
    static let pageInset: CGFloat = 20
    static let rowIconSize: CGFloat = 19
    static let rowIconFrame: CGFloat = 40
    static let fileRowIconSize: CGFloat = 19
    static let fileRowIconFrame: CGFloat = 40
    static let fileRowHeight: CGFloat = 64
    static let appIconSize: CGFloat = 40
    static let emptyIconSize: CGFloat = 34
    static let selectionIconSize: CGFloat = 20
    static let contentCardCornerRadius: CGFloat = 16
    static let contentCardInset: CGFloat = 20
    static let contentCardPadding: CGFloat = 16
    static func sans(_ size: CGFloat = 15, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("PlusJakartaSans-Regular", size: size, relativeTo: style)
    }
    static func mono(_ size: CGFloat = 11) -> Font {
        .custom("JetBrainsMono-Regular", size: size, relativeTo: .caption)
    }
    static func configure() { _ = nativeAppearance }
    private static let nativeAppearance: Void = {
        if let root = Bundle.main.url(forResource: "WQFilesResources", withExtension: "bundle"), let bundle = Bundle(url: root) {
            for name in ["PlusJakartaSans", "JetBrainsMono"] {
                if let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
        let cyan = uiColor(0x00D2FF, 0x006A88)
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = uiColor(0x080B13, 0xF2F7FB)
        navigation.shadowColor = uiColor(0x293246, 0xCCD9E3)
        navigation.titleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = cyan
        UITableView.appearance().backgroundColor = uiColor(0x080B13, 0xF2F7FB)
        UITableViewCell.appearance().backgroundColor = uiColor(0x101522, 0xFFFFFF)
        UITableView.appearance().separatorColor = uiColor(0x293246, 0xCCD9E3)
        UISwitch.appearance().onTintColor = cyan
        let tabs = UITabBarAppearance()
        tabs.configureWithOpaqueBackground()
        tabs.backgroundColor = uiColor(0x0C101C, 0xF2F7FB)
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
        UITabBar.appearance().tintColor = cyan
    }()
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.contentCardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            AppTheme.border.opacity(0.7),
            lineWidth: 0.5
        )
        .accessibilityHidden(true)
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.30), lineWidth: 0.75))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .accessibilityIdentifier("controller-search-field")
                .font(AppTheme.sans())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(
            AppTheme.card,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.75))
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 10)
        .background(AppTheme.pageBackground)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

// Presentation only. All actions, bindings, data and operation ownership stay with the existing views.
struct ControllerCanvas: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack(alignment: .topLeading) {
            AppTheme.pageBackground
            RadialGradient(colors: [AppTheme.accent.opacity(scheme == .dark ? 0.09 : 0.04), .clear], center: .topLeading, startRadius: 0, endRadius: 300)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
struct ControllerCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.card.opacity(0.94))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border.opacity(0.65), lineWidth: 0.75))
            .padding(.vertical, 4)
            .accessibilityHidden(true)
    }
}
extension View {
    func controllerSurface() -> some View {
        self.scrollContentBackground(.hidden).background(ControllerCanvas())
            .toolbarBackground(AppTheme.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
    func controllerRow() -> some View {
        self.listRowBackground(ControllerCardBackground()).listRowSeparator(.hidden)
    }
}
struct ControllerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppTheme.sans(14, relativeTo: .subheadline).weight(.semibold))
            .padding(.horizontal, 18).frame(minHeight: 44)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.24 : 0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.accent.opacity(0.4), lineWidth: 0.75))
            .foregroundStyle(AppTheme.accent).opacity(enabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}
struct ControllerHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Text("3105").font(AppTheme.sans(24, relativeTo: .title2).weight(.heavy)).tracking(1.2)
                    Text("v" + (Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""))
                        .font(AppTheme.mono(10).weight(.bold)).foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppTheme.accent.opacity(0.35), lineWidth: 0.75))
                }
                Text("\(AppInfo.displayMachineName) · iOS \(AppInfo.osVersion)")
                    .font(AppTheme.mono(10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)
    }
}
struct ControllerNavigation: View {
    let sections: [AppSection]
    let language: AppLanguage
    @Binding var selection: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(sections) { section in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { selection = section.rawValue }
                } label: {
                    Text(language.text(section == .installed ? "tab.installed" : "tab.information"))
                        .font(AppTheme.sans(12, relativeTo: .subheadline).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(selection == section.rawValue ? AppTheme.accent : Color.secondary)
                        .background(selection == section.rawValue ? AppTheme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(selection == section.rawValue ? AppTheme.accent.opacity(0.40) : .clear, lineWidth: 1))
                }.buttonStyle(.plain)
                 .accessibilityIdentifier("main-tab-\(section.rawValue)")
                 .accessibilityAddTraits(selection == section.rawValue ? [.isSelected] : [])
            }
        }.padding(4).background(AppTheme.consoleBackground.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
         .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.border.opacity(0.65), lineWidth: 0.75))
         .padding(.horizontal, 20).padding(.bottom, 8)
    }
}
