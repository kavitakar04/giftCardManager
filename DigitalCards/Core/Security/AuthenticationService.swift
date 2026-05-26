import Foundation
import LocalAuthentication

protocol AuthenticationServicing {
    func authenticate(reason: String) async throws
}

enum AuthenticationError: Error, LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Device authentication is unavailable."
        }
    }
}

struct LocalAuthenticationService: AuthenticationServicing {
    func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? AuthenticationError.unavailable
        }

        try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }
}

struct AllowingAuthenticationService: AuthenticationServicing {
    func authenticate(reason: String) async throws {}
}
