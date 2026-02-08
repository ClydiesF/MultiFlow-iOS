import Foundation
import Supabase

@MainActor
final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient
    private(set) var currentUser: AppUser?

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func restoreSession() async {
        if let user = client.auth.currentUser {
            currentUser = AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
        } else {
            currentUser = nil
        }
    }

    func signUp(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signUp(email: email, password: password)
        let user = response.user
        let mapped = AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
        currentUser = mapped
        return mapped
    }

    func signIn(email: String, password: String) async throws -> AppUser {
        let response = try await client.auth.signIn(email: email, password: password)
        let user = response.user
        let mapped = AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
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

        let user = response.user
        let mapped = AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
        currentUser = mapped
        return mapped
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }
}
