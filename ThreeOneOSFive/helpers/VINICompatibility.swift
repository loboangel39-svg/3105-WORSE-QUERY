import Foundation

// Presentation policy only. This resolver never starts or selects an execution
// path in the access engine. A classified method is not a successful execution.
enum VINIMethod: String, Equatable {
    case kernel = "kexploit_opa334"
    case badQuery = "bad_query"
    case worseQuery = "worse_query"
    case none
}

enum VINIRelease: Equatable {
    case final
    case beta(Int)
    case undocumented
}

struct VINICompatibility: Equatable {
    let kernel: VINIMethod
    let sandbox: VINIMethod
    let fallback: VINIMethod
    let documented: Bool
    static let unverified = VINICompatibility(kernel: .none, sandbox: .none,
        fallback: .none, documented: false)
}

enum VINICompatibilityResolver {
    // Seed numbers are evidence, not an inference from the marketing version.
    // Reuse the existing documented seed builds. No undocumented build is added.
    static func release(build: String, major: Int) -> VINIRelease {
        if major == 27, let beta = ExploitSupportPolicy.iOS27BetaNumber(for: build) {
            return .beta(beta)
        }
        let train: Int
        switch major {
        case 17: train = 21
        case 18: train = 22
        case 26: train = 23
        case 27: train = 24
        default: return .undocumented
        }
        // Release builds have no seed suffix. Unrecognized seed strings fail
        // closed; beta 5 and 27.3 beta 1 require an authoritative build mapping.
        let pattern = "^" + String(train) + "[A-Z][0-9]{1,4}$"
        return build.range(of: pattern, options: .regularExpression) == nil ? .undocumented : .final
    }

    static func resolve(major: Int, minor: Int, patch: Int, build: String,
                        release suppliedRelease: VINIRelease? = nil) -> VINICompatibility {
        guard minor >= 0, patch >= 0, !build.isEmpty,
              build.range(of: "^[0-9]{2}[A-Z][0-9]{1,4}[a-z]?$", options: .regularExpression) != nil
        else { return .unverified }
        let release = suppliedRelease ?? self.release(build: build, major: major)
        // Explicit stage metadata must not contradict an already documented seed.
        if let known = ExploitSupportPolicy.iOS27BetaNumber(for: build),
           major != 27 || minor != 0 || patch != 0 || release != .beta(known) { return .unverified }
        switch release {
        case .undocumented: return .unverified
        case .final:
            guard self.release(build: build, major: major) == .final else { return .unverified }
            switch major {
            case 17 where minor < 7 || (minor == 7 && patch == 0):
                return VINICompatibility(kernel: .kernel, sandbox: .none, fallback: .none, documented: true)
            case 18 where minor < 7 || (minor == 7 && patch <= 1):
                return VINICompatibility(kernel: .kernel, sandbox: .none, fallback: .none, documented: true)
            case 26 where minor < 6 || (minor == 6 && patch <= 1):
                return VINICompatibility(kernel: .none, sandbox: .badQuery, fallback: .worseQuery, documented: true)
            case 26 where minor == 6 && patch >= 2 || minor == 7 && patch <= 2:
                return VINICompatibility(kernel: .none, sandbox: .worseQuery, fallback: .none, documented: true)
            case 27 where minor < 2 || (minor == 2 && patch <= 1):
                return VINICompatibility(kernel: .none, sandbox: .worseQuery, fallback: .none, documented: true)
            default: return .unverified
            }
        case .beta(let number):
            guard major == 27, number > 0,
                  build.hasPrefix("24"), build.last?.isLetter == true else { return .unverified }
            if minor == 0 && patch == 0 {
                if (1...4).contains(number) {
                    return VINICompatibility(kernel: .none, sandbox: .badQuery, fallback: .worseQuery, documented: true)
                }
                if number >= 5 {
                    return VINICompatibility(kernel: .none, sandbox: .worseQuery, fallback: .none, documented: true)
                }
            }
            if minor == 3 && patch == 0 && number == 1 {
                return VINICompatibility(kernel: .none, sandbox: .worseQuery, fallback: .none, documented: true)
            }
            return .unverified
        }
    }
}
