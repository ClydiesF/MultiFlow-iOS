import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = false
    @State private var showSplash = true
    @State private var didCompleteMinimumSplash = false

    var body: some View {
        Group {
            if showSplash {
                AppSplashView()
                    .transition(.opacity)
            } else {
                if authViewModel.user == nil {
                    AuthView()
                } else if shouldShowOnboarding && !hasSeenOnboarding {
                    OnboardingView()
                } else {
                    DashboardView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSplash)
        .task {
            if !didCompleteMinimumSplash {
                didCompleteMinimumSplash = true
                try? await Task.sleep(nanoseconds: 750_000_000)
                dismissSplashIfReady()
            }
        }
        .onChange(of: authViewModel.isBootstrapping) { _, _ in
            dismissSplashIfReady()
        }
    }

    private func dismissSplashIfReady() {
        guard didCompleteMinimumSplash, authViewModel.isBootstrapping == false else { return }
        showSplash = false
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager())
}

private struct AppSplashView: View {
    var body: some View {
        ZStack {
            CanvasBackground()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .shadow(color: Color.primaryYellow.opacity(0.2), radius: 18, x: 0, y: 8)

                Text("MultiFlow")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.primaryYellow)
            }
        }
    }
}
