import CryptoKit
import Foundation

// A catalog entry is a snapshot of an imported package, never a preview mapping.
// The server must supply an existing-codec-compatible package/key via the import
// flow. This type neither contacts a server nor invents a decryption protocol.
struct VINIPackageTarget {
    let project: PatchProject
    let packageURL: URL
    let packageDigest: Data
    var id: UUID { project.id }
    // A package identity does not imply a remote target assignment.
}

enum VINIPackageCatalog {
    static func load(fileManager: FileManager = .default) throws -> [VINIPackageTarget] {
        let root = try PatchProjectLibrary.packageRootURL(fileManager: fileManager)
        let files = try fileManager.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
        var entries: [UUID: VINIPackageTarget] = [:]
        var ambiguous = Set<UUID>()
        for file in files where file.pathExtension.lowercased() == "3105" {
            do {
                let entry = try read(file)
                // Two files claiming one identity must not be selected by filename
                // or enumeration order. Keep that identity unavailable until resolved.
                if entries[entry.id] != nil { ambiguous.insert(entry.id) }
                entries[entry.id] = entry
            } catch {
                // No passwords, payloads, keys or decoded paths in diagnostics.
                log("vini.catalog: unavailable imported package")
            }
        }
        return entries.values.filter { !ambiguous.contains($0.id) }.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    // Call again immediately before Apply; do not apply a cached decoded project
    // after its source file has disappeared, changed, or lost its available key.
    static func revalidate(_ target: VINIPackageTarget) throws -> PatchProject {
        let current = try read(target.packageURL)
        guard current.id == target.id, current.packageDigest == target.packageDigest else {
            throw VINIPatchFailure.missingPackage
        }
        return current.project
    }

    private static func read(_ url: URL) throws -> VINIPackageTarget {
        let data = try PatchProjectLibrary.readPackage(at: url)
        let summary = try PatchPackageCodec.inspect(data)
        let decoded: DecodedPatchPackage
        if let key = try PatchKeyStore.load(for: summary) {
            decoded = try PatchPackageCodec.decode(data, contentKey: key)
        } else {
            guard !summary.isPasswordProtected else { throw VINIPatchFailure.lockedPackage }
            decoded = try PatchPackageCodec.decode(data, password: nil)
        }
        guard decoded.project.id == summary.packageID else { throw VINIPatchFailure.invalidManifest }
        return VINIPackageTarget(project: decoded.project, packageURL: url,
            packageDigest: Data(SHA256.hash(data: data)))
    }
}
