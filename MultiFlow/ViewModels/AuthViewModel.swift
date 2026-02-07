import Foundation
import AuthenticationServices
import FirebaseAuth
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var authError: String?
    @Published var didCreateAccount = false

    private var handle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }

    deinit {
        
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String) async {
        authError = nil
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
            didCreateAccount = true
        } catch {
            authError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() {
        authError = nil
        do {
            try Auth.auth().signOut()
        } catch {
            authError = error.localizedDescription
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

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            do {
                _ = try await Auth.auth().signIn(with: firebaseCredential)
                didCreateAccount = true
            } catch {
                authError = error.localizedDescription
            }

        case .failure(let error):
            authError = error.localizedDescription
        }
    }
}

