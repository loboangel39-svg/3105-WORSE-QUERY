import Foundation
import CryptoKit
import Security

enum VINIStagingError: Error, Equatable {
    case signedOut, invalidLicense, blockedLicense, paused, denied, expired, offline, rateLimited, invalidResponse, integrity, keychain, stale
    var message: String {
        switch self {
        case .signedOut: return "Sin sesión"
        case .invalidLicense: return "Clave de licencia no válida"
        case .blockedLicense: return "Cuenta bloqueada"
        case .paused: return "Licencia pausada"
        case .denied: return "Licencia inactiva, revocada o dispositivo no autorizado"
        case .expired: return "Licencia expirada"
        case .offline: return "Sin conexión · estado sin verificar"
        case .rateLimited: return "Espera antes de volver a intentarlo"
        case .integrity: return "Paquete sin integridad verificada"
        case .keychain: return "No se pudo acceder al llavero"
        case .stale: return "Operación cancelada"
        case .invalidResponse: return "Respuesta no válida del Worker"
        }
    }
}

enum VINIStagingEnvironment {
    static let base = URL(string: "https://vini-admin-plans-staging-2b.loboangel39.workers.dev")!
    static let fixtureID = "c0df8b65-a64d-4dca-b262-f12b39831768"
    static let fixtureSHA256 = "92e0aa294e16bfd9ca417f121d162cdeecf46cbae0ab3ca89a2e24a7cf6bb222"
    static let fixtureSize = 2_098_157
    static func date(_ string: String) throws -> Date {
        let precise = ISO8601DateFormatter(); precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: string) ?? ISO8601DateFormatter().date(from: string) { return date }
        throw VINIStagingError.invalidResponse
    }
}

/// Definitive VINI Worker endpoint. Staging remains available only to explicit
/// staging callers; production package coordination must pass this base URL.
enum VINIProductionEnvironment {
    static let base = URL(string: "https://vini-v2-api.loboangel39.workers.dev")!
}

struct VINIStagingProfile: Codable, Equatable {
    let userID: String?
    let username: String
    let plan: String
    let licenseStatus: String
    let licenseExpiresAt: String?
    let serverTime: String
    var stableUserID: String { userID?.isEmpty == false ? userID! : username }
    func validate() throws {
        guard !username.isEmpty, ["basic", "pro"].contains(plan),
              ["active", "paused", "expired", "revoked", "blocked", "inactive", "archived"].contains(licenseStatus)
        else { throw VINIStagingError.invalidResponse }
        _ = try VINIStagingEnvironment.date(serverTime)
        if let expiry = licenseExpiresAt { _ = try VINIStagingEnvironment.date(expiry) }
    }
}
struct VINIStagingPatch: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let version: String?
    let target: VINIRemotePatchTarget?
}
struct VINIRemotePatchTarget: Codable {
    let targetID: String
    let category: String
    let packageID: UUID
    let projectID: UUID
    let packageRevision: String
    let packageSHA256: String
    let fileSize: Int
    let requiredPlan: String?
    let availability: String
}
struct VINIStagingCredentials: Codable {
    var licenseKey: String
    var hwid: String
    var token: String
    var expiresAt: String
}
protocol VINIStagingVault {
    func load() throws -> VINIStagingCredentials?
    func save(_ credentials: VINIStagingCredentials) throws
    func delete() throws
}
struct VINIStagingKeychain: VINIStagingVault {
    let service: String
    private let legacyService = "com.apple.mobile.MobileHouseArrest.vini.staging.session.v1"
    init(service: String = "com.apple.mobile.MobileHouseArrest.vini.session.v1") { self.service = service }
    private func query(for service: String, account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    func load() throws -> VINIStagingCredentials? {
        for (candidate, account) in [(service, "vini-session"), (legacyService, "staging-session")] {
            var q = query(for: candidate, account: account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?; let status = SecItemCopyMatching(q as CFDictionary, &result)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess, let data = result as? Data,
                  let record = try? JSONDecoder().decode(VINIStagingCredentials.self, from: data) else { throw VINIStagingError.keychain }
            return record
        }
        return nil
    }
    func save(_ credentials: VINIStagingCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let current = query(for: service, account: "vini-session")
        let status = SecItemUpdate(current as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw VINIStagingError.keychain }
        var q = current; attributes.forEach { q[$0.key] = $0.value }
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw VINIStagingError.keychain }
    }
    func delete() throws {
        for (candidate, account) in [(service, "vini-session"), (legacyService, "staging-session")] {
            let status = SecItemDelete(query(for: candidate, account: account) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw VINIStagingError.keychain }
        }
    }
}

// No redirects, cookies, shared caches or production fallback. Never log bodies/headers.
final class VINIStagingRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
protocol VINIStagingTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
final class VINIStagingHTTP: VINIStagingTransport {
    static let maximumPackageBytes = 64 * 1024 * 1024
    private let session: URLSession
    private let baseURL: URL
    init(baseURL: URL = VINIProductionEnvironment.base) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false; config.urlCache = nil
        config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config, delegate: VINIStagingRedirectGuard(), delegateQueue: nil)
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard request.url?.scheme == "https", request.url?.host == baseURL.host else { throw VINIStagingError.invalidResponse }
        do {
            if request.url?.path.hasSuffix("/download") == true {
                let (url, response) = try await session.download(for: request)
                defer { try? FileManager.default.removeItem(at: url) }
                guard let http = response as? HTTPURLResponse else { throw VINIStagingError.invalidResponse }
                let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
                let bytes = try handle.read(upToCount: Self.maximumPackageBytes + 1) ?? Data()
                guard bytes.count <= Self.maximumPackageBytes else { throw VINIStagingError.integrity }
                return (bytes, http)
            }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, data.count <= 2 * 1024 * 1024 else { throw VINIStagingError.invalidResponse }
            return (data, http)
        } catch let error as VINIStagingError { throw error }
        catch { throw VINIStagingError.offline }
    }
}

actor VINIStagingClient {
    func authorizationLifetime(_ profile: VINIStagingProfile) throws -> TimeInterval {
        guard profile.licenseStatus == "active", let credentials else { throw VINIStagingError.denied }
        let server = try VINIStagingEnvironment.date(profile.serverTime)
        var lifetime = try VINIStagingEnvironment.date(credentials.expiresAt).timeIntervalSince(server)
        if let expiry = profile.licenseExpiresAt { lifetime = min(lifetime, try VINIStagingEnvironment.date(expiry).timeIntervalSince(server)) }
        guard lifetime > 0, lifetime.isFinite else { throw VINIStagingError.expired }
        return lifetime
    }
    private let transport: VINIStagingTransport
    private let vault: VINIStagingVault
    private let baseURL: URL
    private var credentials: VINIStagingCredentials?
    private var loaded = false
    private var generation = 0
    private var refreshTask: Task<VINIStagingProfile, Error>?
    private var lastLogin: TimeInterval = -.infinity
    init(baseURL: URL = VINIProductionEnvironment.base, transport: VINIStagingTransport? = nil, vault: VINIStagingVault = VINIStagingKeychain()) {
        self.baseURL = baseURL
        self.transport = transport ?? VINIStagingHTTP(baseURL: baseURL)
        self.vault = vault
    }
    private func load() throws { if !loaded { credentials = try vault.load(); loaded = true } }
    private func request(_ path: String, token: String? = nil, body: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        var r = URLRequest(url: baseURL.appendingPathComponent(path))
        r.cachePolicy = .reloadIgnoringLocalCacheData
        if let token { r.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let body { r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type"); r.httpBody = try JSONEncoder().encode(body) }
        return try await transport.send(r)
    }
    private func failure(_ data: Data, _ status: Int) -> VINIStagingError {
        if status == 429 { return .rateLimited }
        if status >= 500 { return .offline }
        let text = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] as? String ?? ""
        if text.lowercased().contains("paused") { return .paused }
        if text.lowercased().contains("expired") { return .expired }
        if text.lowercased().contains("invalid license") { return .invalidLicense }
        if text.lowercased().contains("blocked") { return .blockedLicense }
        if status == 403 { return .denied }
        return status == 401 ? .signedOut : .invalidResponse
    }
    func login(licenseKey: String) async throws -> VINIStagingProfile {
        try load()
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.count <= 200 else { throw VINIStagingError.signedOut }
        generation += 1; refreshTask?.cancel(); refreshTask = nil
        let hwid = credentials?.hwid ?? UUID().uuidString
        credentials = VINIStagingCredentials(licenseKey: key, hwid: hwid, token: "", expiresAt: "")
        // Switching accounts must not restore an older account on the next launch
        // if the new login is rejected or loses connectivity.
        try vault.save(credentials!)
        return try await profile()
    }
    func logout() throws {
        try load()
        generation += 1; refreshTask?.cancel(); refreshTask = nil
        // Device identity survives logout; rotating it would lock out a license
        // already bound by the server. Remove license/token, retain only HWID.
        if let hwid = credentials?.hwid {
            let identity = VINIStagingCredentials(licenseKey: "", hwid: hwid, token: "", expiresAt: "")
            try vault.save(identity); credentials = identity
        } else { try vault.delete(); credentials = nil }
    }
    func hasStoredIdentity() throws -> Bool {
        try load()
        return !(credentials?.licenseKey.isEmpty ?? true)
    }
    func profile(forceRevalidation: Bool = false) async throws -> VINIStagingProfile {
        try load()
        if let task = refreshTask { return try await task.value }
        let epoch = generation
        let task = Task { try await self.fetchProfile(epoch: epoch, forceRevalidation: forceRevalidation) }
        refreshTask = task
        defer { if generation == epoch { refreshTask = nil } }
        return try await task.value
    }
    private func fetchProfile(epoch: Int, forceRevalidation: Bool = false) async throws -> VINIStagingProfile {
        guard let saved = credentials, !saved.licenseKey.isEmpty else { throw VINIStagingError.signedOut }
        if !saved.token.isEmpty && !forceRevalidation {
            let (bytes, response) = try await request("api/app/me", token: saved.token)
            guard generation == epoch else { throw VINIStagingError.stale }
            if response.statusCode == 200 {
                let p = try JSONDecoder().decode(VINIStagingProfile.self, from: bytes); try p.validate(); return p
            }
            guard response.statusCode == 401 else { throw failure(bytes, response.statusCode) }
            credentials?.token = ""; try vault.save(credentials!)
        }
        // Exactly one explicit revalidation, coalesced across callers, with bounded retries.
        guard forceRevalidation || ProcessInfo.processInfo.systemUptime - lastLogin >= 30 else { throw VINIStagingError.rateLimited }
        lastLogin = ProcessInfo.processInfo.systemUptime
        let (bytes, response) = try await request("api/app/validate-license", body: ["licenseKey": saved.licenseKey, "hwid": saved.hwid])
        guard generation == epoch else { throw VINIStagingError.stale }
        guard response.statusCode == 200 else { throw failure(bytes, response.statusCode) }
         struct Login: Decodable {
             let valid: Bool
             let token: String
             let expiresAt: String
             let username: String?
             let userID: String?
             let isPremium: Bool?
             let plan: String?
             let licenseExpiresAt: String?
             let serverTime: String?
         }
         let result = try JSONDecoder().decode(Login.self, from: bytes)
         let serverTime = result.serverTime ?? ISO8601DateFormatter().string(from: Date())
         guard result.valid, !result.token.isEmpty, let username = result.username, !username.isEmpty,
               try VINIStagingEnvironment.date(result.expiresAt) > VINIStagingEnvironment.date(serverTime) else { throw VINIStagingError.invalidLicense }
         let plan = result.plan ?? (result.isPremium == true ? "pro" : "basic")
         let p = VINIStagingProfile(userID: result.userID, username: username, plan: plan,
             licenseStatus: "active", licenseExpiresAt: result.licenseExpiresAt ?? result.expiresAt,
             serverTime: serverTime)
         try p.validate()
         guard try VINIStagingEnvironment.date(result.expiresAt) > VINIStagingEnvironment.date(p.serverTime)
        else { throw VINIStagingError.invalidResponse }
        let current = VINIStagingCredentials(licenseKey: saved.licenseKey, hwid: saved.hwid, token: result.token, expiresAt: result.expiresAt)
        try vault.save(current); credentials = current
        return p
    }
    private func authorizedResponse(_ path: String) async throws -> (Data, HTTPURLResponse) {
        try load(); let epoch = generation
        guard let token = credentials?.token, !token.isEmpty else { throw VINIStagingError.signedOut }
        var (bytes, response) = try await request(path, token: token)
        guard generation == epoch else { throw VINIStagingError.stale }
        if response.statusCode == 401 {
            _ = try await profile(forceRevalidation: true)
            guard generation == epoch, let newToken = credentials?.token else { throw VINIStagingError.stale }
            (bytes, response) = try await request(path, token: newToken)
        }
        guard generation == epoch else { throw VINIStagingError.stale }
        guard response.statusCode == 200 else { throw failure(bytes, response.statusCode) }
        return (bytes, response)
    }
    private func authorized(_ path: String) async throws -> Data {
        try await (authorizedResponse(path)).0
    }
    func catalog() async throws -> [VINIStagingPatch] {
        struct Catalog: Decodable { let patches: [VINIStagingPatch] }
        return try JSONDecoder().decode(Catalog.self, from: await authorized("api/app/patches")).patches
    }
    func downloadPackage(id: String) async throws -> Data {
        try await downloadPackageWithMetadata(id: id).data
    }
    struct AuthorizedPackageDownload {
        let data: Data
        let headers: [AnyHashable: Any]
        let contentKey: Data?
    }
    func downloadPackageWithMetadata(id: String) async throws -> AuthorizedPackageDownload {
        let response = try await authorizedResponse("api/app/patches/" + id + "/download")
        let headers = response.1.allHeaderFields
        let raw = headers.first { String(describing: $0.key).lowercased() == "x-content-key" }.map { String(describing: $0.value) }
        let contentKey: Data?
        if let raw, raw.count == 64, raw.allSatisfy({ $0.isHexDigit }) {
            contentKey = Data((0..<32).compactMap { index in
                let start = raw.index(raw.startIndex, offsetBy: index * 2)
                let end = raw.index(start, offsetBy: 2)
                return UInt8(raw[start..<end], radix: 16)
            })
        } else { contentKey = nil }
        return AuthorizedPackageDownload(data: response.0, headers: headers, contentKey: contentKey)
    }
    func verifiedTestBytes(id: String) async throws -> Data {
        // The current API has no digest field. Only the independently pinned 2C fixture
        // can be marked verified; do not invent a checksum for arbitrary packages.
        guard id == VINIStagingEnvironment.fixtureID else { throw VINIStagingError.integrity }
        let cache = try packageCacheURL(id: id)
        if let cached = try? Data(contentsOf: cache), try validateFixture(cached) {
            return cached
        }
        let bytes = try await authorized("api/app/patches/" + id + "/download")
        return bytes
    }
    private func packageCacheURL(id: String) throws -> URL {
        let root = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VINIStagingVerified", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(id + ".3105")
    }
    private func validateFixture(_ bytes: Data) throws -> Bool {
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard bytes.count == VINIStagingEnvironment.fixtureSize, digest == VINIStagingEnvironment.fixtureSHA256 else { return false }
        let decoded = try PatchPackageCodec.decode(bytes, password: nil)
        return decoded.project.id.uuidString == "E4F7CF4A-D0D9-4150-93DE-17AACCD5F037"
    }
    private func storeFixture(_ bytes: Data, id: String) throws {
        guard try validateFixture(bytes) else { throw VINIStagingError.integrity }
        let destination = try packageCacheURL(id: id)
        let temporary = destination.deletingLastPathComponent().appendingPathComponent("." + UUID().uuidString + ".partial")
        try bytes.write(to: temporary, options: .atomic)
        guard try validateFixture(Data(contentsOf: temporary)) else { try? FileManager.default.removeItem(at: temporary); throw VINIStagingError.integrity }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.replaceItemAt(destination, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }
    func downloadTestPackage(id: String) async throws -> String {
        let catalog = try await catalog()
        guard catalog.contains(where: { $0.id == id }) else { throw VINIStagingError.denied }
        let bytes = try await verifiedTestBytes(id: id)
        let decoded = try PatchPackageCodec.decode(bytes, password: nil)
        try storeFixture(bytes, id: id)
        let directory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VINIStagingVerified", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bytes.write(to: directory.appendingPathComponent("TEST2C-transport.3105"), options: .atomic)
        return decoded.project.name
    }
}
