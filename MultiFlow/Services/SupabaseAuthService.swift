import Foundation
import Supabase
import Auth

@MainActor
final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient
    private(set) var currentUser: AppUser?

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func restoreSession() async {
        if let session = client.auth.currentSession {
            if session.isExpired {
                _ = try? await client.auth.refreshSession()
            }
            currentUser = mappedUser(from: client.auth.currentUser)
            return
        }

        for await (event, session) in client.auth.authStateChanges {
            guard [.initialSession, .signedIn, .tokenRefreshed, .signedOut].contains(event) else { continue }
            if let session {
                if session.isExpired {
                    _ = try? await client.auth.refreshSession()
                }
                currentUser = mappedUser(from: client.auth.currentUser ?? session.user)
            } else {
                currentUser = nil
            }
            break
        }
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signUp(email: email, password: password)
        guard response.session != nil || client.auth.currentSession != nil else {
            throw AuthServiceError.sessionNotEstablishedAfterSignUp
        }
        guard let mapped = mappedUser(from: response.user) else {
            throw AuthServiceError.invalidSessionResponse
        }
        currentUser = mapped
        return mapped
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signIn(email: email, password: password)
        guard client.auth.currentSession != nil else {
            throw AuthServiceError.sessionNotEstablishedAfterSignIn
        }
        guard let mapped = mappedUser(from: response.user) else {
            throw AuthServiceError.invalidSessionResponse
        }
        currentUser = mapped
        return mapped
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AppUser {
        let response = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        guard let mapped = mappedUser(from: response.user) else {
            throw AuthServiceError.invalidSessionResponse
        }
        currentUser = mapped
        return mapped
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    private func mappedUser(from user: User?) -> AppUser? {
        guard let user else { return nil }
        return AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
    }
}

private enum AuthServiceError: LocalizedError {
    case invalidSessionResponse
    case sessionNotEstablishedAfterSignUp
    case sessionNotEstablishedAfterSignIn

    var errorDescription: String? {
        switch self {
        case .invalidSessionResponse:
            return "Auth session could not be established. Please try again."
        case .sessionNotEstablishedAfterSignUp:
            return "Account created, but no active session was started. Verify your email (if required), then sign in."
        case .sessionNotEstablishedAfterSignIn:
            return "Sign-in succeeded, but no active session was returned. Please sign in again."
        }
    }
}
