import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var authError: String?
    @Published var didCreateAccount = false

    private var currentNonce: String?
    private let authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol? = nil) {
        self.authService = authService ?? SupabaseAuthService(client: SupabaseManager.shared.client)
        Task {
            await self.authService.restoreSession()
            self.user = self.authService.currentUser
        }
    }

    func signUp(email: String, password: String) async {
        authError = nil
        do {
            user = try await authService.signUp(email: email, password: password)
            didCreateAccount = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        do {
            user = try await authService.signIn(email: email, password: password)
            didCreateAccount = false
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        authError = nil
        Task {
            do {
                try await authService.signOut()
                user = nil
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInHelper.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInHelper.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        authError = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Unable to read Apple ID credential."
                return
            }

            guard let nonce = currentNonce else {
                authError = "Invalid state: missing login nonce."
                return
            }

            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                authError = "Unable to fetch identity token."
                return
            }

            do {
                user = try await authService.signInWithApple(idToken: tokenString, nonce: nonce)
                didCreateAccount = true
            } catch {
                authError = error.localizedDescription
            }

        case .failure(let error):
            authError = error.localizedDescription
        }
    }
}
