import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    var body: some View {
        TabView {
            NavigationStack {
                PortfolioView()
            }
            .tabItem {
                Label("Portfolio", systemImage: "building.2")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(Color.richBlack)
        .onAppear {
            gradeProfileStore.listen()
        }
        .onDisappear {
            gradeProfileStore.stopListening()
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(PropertyStore())
        .environmentObject(GradeProfileStore())
        .environmentObject(AuthViewModel())
}
