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

        guard client.auth.currentSession != nil else {
            throw AuthServiceError.sessionNotEstablishedAfterAppleSignIn
        }

        let resolvedUser = response.user
        guard let mapped = mappedUser(from: resolvedUser) else {
            throw AuthServiceError.invalidSessionResponse
        }
        currentUser = mapped
        return mapped
    }

    func sendPasswordReset(email: String, redirectTo: URL?) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo)
    }

    func verifyRecoveryToken(email: String, token: String) async throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw AuthServiceError.invalidRecoveryToken }

        do {
            _ = try await client.auth.verifyOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                token: value,
                type: .recovery
            )
        } catch {
            // Some templates expose token hash instead of raw OTP.
            do {
                _ = try await client.auth.verifyOTP(tokenHash: value, type: .recovery)
            } catch {
                throw AuthServiceError.invalidRecoveryToken
            }
        }

        currentUser = mappedUser(from: client.auth.currentUser)
    }

    func updatePassword(newPassword: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func handleIncomingURL(_ url: URL) async throws -> Bool {
        let isRecovery = isRecoveryLink(url)
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            // Fallback for email clients that strip/mutate redirect flow.
            // If token_hash is present, verify recovery directly.
            if isRecovery, let tokenHash = firstValue(in: url, keys: ["token_hash", "token"]) {
                _ = try await client.auth.verifyOTP(
                    tokenHash: tokenHash,
                    type: .recovery
                )
            } else {
                throw error
            }
        }
        currentUser = mappedUser(from: client.auth.currentUser)
        return isRecovery
    }

    func signOut() async throws {
        try await client.auth.signOut()
        currentUser = nil
    }

    private func mappedUser(from user: User?) -> AppUser? {
        guard let user else { return nil }
        return AppUser(id: user.id.uuidString, email: user.email, isAnonymous: false)
    }

    private func isRecoveryLink(_ url: URL) -> Bool {
        firstValue(in: url, keys: ["type"])?.lowercased() == "recovery"
    }

    private func firstValue(in url: URL, keys: [String]) -> String? {
        let pairs = ((url.query ?? "") + "&" + (url.fragment ?? ""))
            .split(separator: "&")
            .map(String.init)

        for pair in pairs {
            let tokens = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard tokens.count == 2 else { continue }
            let key = tokens[0].lowercased()
            if keys.contains(where: { $0.lowercased() == key }) {
                return tokens[1].removingPercentEncoding ?? tokens[1]
            }
        }
        return nil
    }
}

private enum AuthServiceError: LocalizedError {
    case invalidSessionResponse
    case sessionNotEstablishedAfterSignUp
    case sessionNotEstablishedAfterSignIn
    case sessionNotEstablishedAfterAppleSignIn
    case invalidRecoveryToken

    var errorDescription: String? {
        switch self {
        case .invalidSessionResponse:
            return "Auth session could not be established. Please try again."
        case .sessionNotEstablishedAfterSignUp:
            return "Account created, but no active session was started. Verify your email (if required), then sign in."
        case .sessionNotEstablishedAfterSignIn:
            return "Sign-in succeeded, but no active session was returned. Please sign in again."
        case .sessionNotEstablishedAfterAppleSignIn:
            return "Apple sign-in succeeded, but no active session was returned. Please try again."
        case .invalidRecoveryToken:
            return "Invalid or expired recovery token. Request a new reset token and try again."
        }
    }
}
