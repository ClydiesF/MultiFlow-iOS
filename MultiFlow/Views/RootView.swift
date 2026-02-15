import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("shouldShowOnboarding") private var shouldShowOnboarding = false

    var body: some View {
        Group {
            if authViewModel.user == nil {
                AuthView()
            } else if shouldShowOnboarding && !hasSeenOnboarding {
                OnboardingView()
            } else {
                DashboardView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(SubscriptionManager())
}
