import XCTest

final class UICleanupTests: XCTestCase {
    func testNavigationAndDefaultStartupWithoutOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "-feature.developer_mode.enabled", "NO"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertEqual(tabs.buttons.count, 3)
        XCTAssertTrue(tabs.buttons["Instalados"].isSelected)
        for title in ["Archivos", "Buscar", "Instalados"] {
            let tab = tabs.buttons[title]
            XCTAssertTrue(tab.exists, title)
            tab.tap()
            XCTAssertTrue(tab.isSelected, app.debugDescription)
        }
        XCTAssertFalse(app.alerts.firstMatch.exists, app.debugDescription)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Inicio español, tres pestañas sin onboarding"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let addButton = app.buttons["Añadir proyecto de parche"]
        XCTAssertTrue(addButton.exists, app.debugDescription)
        addButton.tap()
        XCTAssertTrue(app.buttons["Importar .3105"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Importar .3105"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }
    func testExplicitEnglishPreferenceIsRespected() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "-appLanguage", "en"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Installed"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(app.tabBars.buttons["Files"].exists)
        XCTAssertTrue(app.tabBars.buttons["Search"].exists)
    }
    func testNavigationStateAndHiddenLegacyRoutes() {
        for developer in [false, true] {
            let visibility = FeatureVisibility(developerModeEnabled: developer)
            XCTAssertEqual(visibility.visibleSections, [.installed, .files, .search])
            var state = AppTabNavigationState()
            XCTAssertEqual(state.selectedTab, 3)
            for tab in [AppSection.home, .new, .sources] {
                state.select(tab.rawValue)
                state.reconcileSelection(with: visibility)
                XCTAssertEqual(state.selectedTab, 3)
            }
            state.select(AppSection.files.rawValue)
            state.reconcileSelection(with: visibility)
            XCTAssertEqual(state.selectedTab, 4)
        }
    }
    func testRealPatchPackageRoundTrip() throws {
        let rule = PatchRule(bundleID: "org.example.fixture", relativePath: "Documents/test.txt", replacementFilename: "test.txt", replacementData: Data("contenido".utf8))
        let project = PatchProject(name: "Prueba de importación", rules: [rule])
        let encoded = try PatchPackageCodec.encodeNew(project: project, password: nil)
        let decoded = try PatchPackageCodec.decode(encoded.data, password: nil)
        XCTAssertEqual(decoded.project, project)
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("3105")
        try encoded.data.write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }
        let imported = try PatchPackageCodec.decode(Data(contentsOf: path), password: nil)
        XCTAssertEqual(imported.project.rules.first?.replacementData, Data("contenido".utf8))
    }
}
