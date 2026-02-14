import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.openURL) private var openURL
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = false
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var appear = false
    private let termsURL = URL(string: "https://multiflow.app/terms")
    private let privacyURL = URL(string: "https://multiflow.app/privacy")

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 18) {
                        LabeledTextField(title: "Email", text: $email, keyboard: .emailAddress)
                        LabeledSecureField(title: "Password", text: $password)
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.cardSurface)
                            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
                    )

                    if let error = authViewModel.authError {
                        Text(error)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(isLogin ? "Sign In" : "Create Account") {
                        Task {
                            if isLogin {
                                await authViewModel.signIn(email: email, password: password)
                            } else {
                                await authViewModel.signUp(email: email, password: password)
                                if authViewModel.didCreateAccount {
                                    shouldShowOnboarding = true
                                }
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    SignInWithAppleButton(.signIn) { request in
                        authViewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task {
                            await authViewModel.handleAppleCompletion(result)
                            if authViewModel.didCreateAccount {
                                shouldShowOnboarding = true
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)

                    Button(isLogin ? "Need an account? Sign up" : "Already have an account? Sign in") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isLogin.toggle() }
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))

                    legalFooter
                }
                .padding(24)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 16)
                .animation(.easeOut(duration: 0.6), value: appear)
            }
        }
        .onAppear { appear = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("MultiFlow")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text(isLogin ? "Welcome back." : "Start evaluating deals with clarity.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Evaluate. Grade. Export.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text("By continuing, you agree to our Terms & Conditions and Privacy Policy.")
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.58))
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Button("Terms & Conditions") {
                    guard let termsURL else { return }
                    openURL(termsURL)
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)

                Circle()
                    .fill(Color.richBlack.opacity(0.28))
                    .frame(width: 4, height: 4)

                Button("Privacy Policy") {
                    guard let privacyURL else { return }
                    openURL(privacyURL)
                }
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
