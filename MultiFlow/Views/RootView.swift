import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if authViewModel.user != nil {
                DashboardView()
            } else {
                AuthView()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
}
