import Foundation
import Security

// MARK: - Keychain Manager
// Guarda credenciales en el Keychain de iOS.
// El Keychain SOBREVIVE a reinstalaciones de la app.
// Esto permite auto-login sin requerir nueva licencia al reinstalar.

final class KeychainManager {
    static let shared = KeychainManager()
    
    // Shares the production session record written by VINIStagingKeychain.
    // This is an adapter only; it does not create a second authentication state.
    private let service = "com.apple.mobile.MobileHouseArrest.vini.session.v1"
    private let sessionAccount = "vini-session"
    
    // Keys
    private let licenseKeyKey = "vini_license_key"
    private let hwidKey = "vini_hwid"
    private let authTokenKey = "vini_auth_token"
    private let usernameKey = "vini_username"
    
    // MARK: - Save
    
    func saveLicenseKey(_ value: String) {
        save(key: licenseKeyKey, value: value)
    }
    
    func saveHWID(_ value: String) {
        save(key: hwidKey, value: value)
    }
    
    func saveAuthToken(_ value: String) {
        save(key: authTokenKey, value: value)
    }
    
    func saveUsername(_ value: String) {
        save(key: usernameKey, value: value)
    }
    
    // MARK: - Load
    
    func loadLicenseKey() -> String? {
        return load(key: licenseKeyKey)
    }
    
    func loadHWID() -> String? {
        return load(key: hwidKey)
    }
    
    func loadAuthToken() -> String? {
        return load(key: authTokenKey)
    }
    
    func loadUsername() -> String? {
        return load(key: usernameKey)
    }
    
    // MARK: - Delete
    
    func deleteAll() {
        delete(key: licenseKeyKey)
        delete(key: hwidKey)
        delete(key: authTokenKey)
        delete(key: usernameKey)
    }
    
    func deleteAuthToken() {
        delete(key: authTokenKey)
    }
    
    // MARK: - Generate Persistent HWID
    // Genera un UUID y lo guarda en Keychain.
    // Este UUID NO cambia al reinstalar la app.
    
    func getOrCreatePersistentHWID() -> String {
        if let existing = loadHWID() {
            return existing
        }
        
        // Generar nuevo HWID persistente
        let newHWID = UUID().uuidString
        saveHWID(newHWID)
        return newHWID
    }
    
    // MARK: - Check if has saved credentials
    
    func hasSavedCredentials() -> Bool {
        return loadLicenseKey() != nil
    }
    
    // MARK: - Private helpers
    
    private func save(key: String, value: String) {
        if key == authTokenKey || key == licenseKeyKey || key == hwidKey {
            updateProductionSession(key: key, value: value)
            return
        }
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func load(key: String) -> String? {
        if key == authTokenKey || key == licenseKeyKey || key == hwidKey {
            return readProductionSession()[key]
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    private func delete(key: String) {
        if key == authTokenKey || key == licenseKeyKey || key == hwidKey {
            updateProductionSession(key: key, value: "")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        
        SecItemDelete(query as CFDictionary)
    }

    private func readProductionSession() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: sessionAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return [licenseKeyKey: object["licenseKey"] as? String ?? "",
                hwidKey: object["hwid"] as? String ?? "",
                authTokenKey: object["token"] as? String ?? "",
                usernameKey: object["username"] as? String ?? ""]
    }

    private func updateProductionSession(key: String, value: String) {
        let current = readProductionSession()
        var record: [String: String] = [
            "licenseKey": current[licenseKeyKey] ?? "",
            "hwid": current[hwidKey] ?? "",
            "token": current[authTokenKey] ?? "",
            "expiresAt": ""
        ]
        let productionKey = [licenseKeyKey: "licenseKey", hwidKey: "hwid", authTokenKey: "token"][key]
        if let productionKey { record[productionKey] = value }
        guard let data = try? JSONSerialization.data(withJSONObject: record) else { return }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: sessionAccount]
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) != errSecSuccess {
            var add = query; attributes.forEach { add[$0.key] = $0.value }
            _ = SecItemAdd(add as CFDictionary, nil)
        }
    }
}
