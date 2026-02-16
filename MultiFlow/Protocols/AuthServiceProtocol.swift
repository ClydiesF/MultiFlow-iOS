import Foundation
import AuthenticationServices

@MainActor
protocol AuthServiceProtocol {
    var currentUser: AppUser? { get }

    func restoreSession() async
    func signUp(email: String, password: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func signInWithApple(idToken: String, nonce: String) async throws -> AppUser
    func sendPasswordReset(email: String, redirectTo: URL?) async throws
    func verifyRecoveryToken(email: String, token: String) async throws
    func updatePassword(newPassword: String) async throws
    func handleIncomingURL(_ url: URL) async throws -> Bool
    func signOut() async throws
}
