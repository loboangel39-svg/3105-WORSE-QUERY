import Foundation

struct VINIProductionCategory: Equatable, Identifiable {
    let id: Int
    let displayName: String
    var identity: Int { id }
}

enum VINIProductionCategoryRegistry {
    static let all: [VINIProductionCategory] = [
        VINIProductionCategory(id: 1, displayName: "Combat"),
        VINIProductionCategory(id: 2, displayName: "Visuals"),
        VINIProductionCategory(id: 3, displayName: "Offsets")
    ]
    static func categoryID(for serverValue: String) -> Int? {
        switch serverValue.lowercased() { case "combat": return 1; case "visuals": return 2; case "offsets": return 3; default: return nil }
    }
    static func displayName(for id: Int) -> String? { all.first(where: { $0.id == id })?.displayName }
    static func dashboardCategory(for id: Int) -> VINICategory? {
        switch id { case 1: return .combat; case 2: return .visuals; case 3: return .offsets; default: return nil }
    }
}
