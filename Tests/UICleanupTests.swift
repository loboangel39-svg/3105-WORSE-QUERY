import XCTest

final class UICleanupTests: XCTestCase {
    func testNavigationAndDefaultStartupWithoutOnboarding() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "-feature.developer_mode.enabled", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "main-tab-")).count, 3)
        XCTAssertTrue(app.buttons["main-tab-3"].isSelected)
        for title in ["Archivos", "Buscar", "Instalados"] {
            let id = title == "Archivos" ? 4 : title == "Buscar" ? 5 : 3
            let tab = app.buttons["main-tab-\(id)"]
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
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertEqual(app.buttons["main-tab-3"].label, "Installed")
        XCTAssertTrue(app.buttons["main-tab-4"].exists)
        XCTAssertTrue(app.buttons["main-tab-5"].exists)
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
    private func capture(_ name: String, app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
    func testVisualScreensAndRealFolderNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "-appLanguage", "es", "-interface.appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 30))
        capture("01-Instalados-oscuro", app: app)
        app.buttons["main-tab-4"].tap()
        let workspace = app.buttons["files-workspace"]
        XCTAssertTrue(workspace.waitForExistence(timeout: 15), app.debugDescription)
        capture("02-Archivos-oscuro", app: app)
        workspace.tap()
        XCTAssertTrue(app.collectionViews["folder-browser"].waitForExistence(timeout: 15) || app.tables["folder-browser"].exists || app.otherElements["folder-browser"].exists, app.debugDescription)
        capture("04-Explorador-carpetas", app: app)
        app.buttons["main-tab-5"].tap()
        let search = app.textFields["controller-search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("consulta-3105-sin-coincidencias")
        XCTAssertTrue(app.staticTexts["No hay paquetes coincidentes"].waitForExistence(timeout: 10))
        capture("03-Buscar-consulta-real", app: app)
        app.buttons["Borrar búsqueda"].tap()
        XCTAssertEqual(search.value as? String, "Buscar paquetes, autores o bundles")
        app.buttons["main-tab-3"].tap()
        app.buttons["Añadir proyecto de parche"].tap()
        XCTAssertTrue(app.buttons["Importar .3105"].waitForExistence(timeout: 5))
        capture("06-Menu-importacion", app: app)
    }
    func testSettingsAndIntegratedUIKitPresentation() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "--simulate-settings", "-appLanguage", "es", "-interface.appearance", "dark"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 30))
        capture("05-Ajustes-oscuro", app: app)
        let tools = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "WQFiles ·")).firstMatch
        for _ in 0..<5 {
            if tools.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(tools.isHittable, app.debugDescription)
        tools.tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
        capture("07-WQFiles-UIKit", app: app)
    }
    func testLightModeLargeTypeAndTouchTargets() {
        let app = XCUIApplication()
        app.launchArguments = ["--simulate-access", "-appLanguage", "es", "-interface.appearance", "light", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-3"].waitForExistence(timeout: 30))
        let tabs = [3,4,5].map { app.buttons["main-tab-\($0)"] }
        for tab in tabs {
            XCTAssertTrue(tab.isHittable)
            XCTAssertGreaterThanOrEqual(tab.frame.height, 44)
        }
        XCTAssertLessThanOrEqual(tabs[0].frame.maxX, tabs[1].frame.minX)
        XCTAssertLessThanOrEqual(tabs[1].frame.maxX, tabs[2].frame.minX)
        capture("08-Claro-DynamicType-accesibilidad", app: app)
    }

}
