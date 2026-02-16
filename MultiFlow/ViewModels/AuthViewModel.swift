import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var authError: String?
    @Published var authNotice: String?
    @Published var isRecoveringPassword = false
    @Published var didCreateAccount = false

    private var currentNonce: String?
    private let authService: AuthServiceProtocol
    private let passwordRecoveryURL = URL(string: "multiflow://recovery")

    init(authService: AuthServiceProtocol? = nil) {
        self.authService = authService ?? SupabaseAuthService(client: SupabaseManager.shared.client)
        Task {
            await self.authService.restoreSession()
            self.user = self.authService.currentUser
        }
    }

    func signUp(email: String, password: String) async {
        authError = nil
        authNotice = nil
        do {
            user = try await authService.signUp(email: email, password: password)
            didCreateAccount = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        authNotice = nil
        do {
            user = try await authService.signIn(email: email, password: password)
            didCreateAccount = false
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        authError = nil
        authNotice = nil
        isRecoveringPassword = false
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
        authNotice = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Unable to read Apple ID credential."
                return
            }

            guard let nonce = currentNonce else {
                // Graceful recovery for duplicate completion callbacks.
                await authService.restoreSession()
                if let existing = authService.currentUser {
                    user = existing
                    return
                }
                authError = "Invalid state: missing login nonce. Please try Sign in with Apple again."
                return
            }
            currentNonce = nil

            guard let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                authError = "Unable to fetch identity token."
                return
            }

            do {
                user = try await authService.signInWithApple(idToken: tokenString, nonce: nonce)
                // Apple only returns email/fullName on first authorization for an app.
                didCreateAccount = credential.email != nil || credential.fullName != nil
            } catch {
                authError = error.localizedDescription
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            authError = error.localizedDescription
        }
    }

    func sendPasswordReset(email: String) async {
        authError = nil
        authNotice = nil
        do {
            try await authService.sendPasswordReset(email: email, redirectTo: passwordRecoveryURL)
            let notice = "If the email is in our system, we sent a recovery token."
            authNotice = notice
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard let self else { return }
                if self.authNotice == notice {
                    self.authNotice = nil
                }
            }
        } catch {
            authError = error.localizedDescription
        }
    }

    func verifyRecoveryToken(email: String, token: String) async -> Bool {
        authError = nil
        authNotice = nil
        do {
            try await authService.verifyRecoveryToken(email: email, token: token)
            isRecoveringPassword = true
            authNotice = "Token verified. Set your new password."
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func updatePassword(newPassword: String) async -> Bool {
        authError = nil
        authNotice = nil
        do {
            try await authService.updatePassword(newPassword: newPassword)
            isRecoveringPassword = false
            authNotice = "Password updated successfully."
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func handleIncomingURL(_ url: URL) async {
        do {
            let isRecovery = try await authService.handleIncomingURL(url)
            if isRecovery {
                isRecoveringPassword = true
                authNotice = "Recovery verified. Set your new password."
            } else {
                user = authService.currentUser
            }
        } catch {
            authError = error.localizedDescription
        }
    }
}
