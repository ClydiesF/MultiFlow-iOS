import Foundation
import AuthenticationServices

@MainActor
protocol AuthServiceProtocol {
    var currentUser: AppUser? { get }

    func restoreSession() async
    func signUp(email: String, password: String) async throws -> AppUser
    func signIn(email: String, password: String) async throws -> AppUser
    func signInWithApple(idToken: String, nonce: String) async throws -> AppUser
    func signOut() async throws
}
