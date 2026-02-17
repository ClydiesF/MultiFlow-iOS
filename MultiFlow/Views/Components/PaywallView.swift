import SwiftUI
import UIKit

struct PremiumPaywallView: View {
    private struct ProFeature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let caption: String
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var usageManager = RentCastUsageManager.shared

    @State private var dragOffset: CGSize = .zero
    @State private var errorText: String?

    private let features: [ProFeature] = [
        .init(icon: "bolt.fill", title: "Auto-Fill", caption: "Address completion in seconds"),
        .init(icon: "map.fill", title: "Nationwide Taxes", caption: "State-aware tax defaults"),
        .init(icon: "chart.bar.fill", title: "Market Insights", caption: "Live market/rent intelligence"),
        .init(icon: "fuelpump.fill", title: "25 Insight Credits", caption: "Monthly API-backed data budget")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.04, blue: 0.05), Color(red: 0.09, green: 0.09, blue: 0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        heroCard
                        creditsSummaryCard
                        planPicker
                        benefitsGrid
                        mainCTA
                        legalLinks
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }
        }
        .task {
            subscriptionManager.configureIfNeeded()
            await subscriptionManager.refreshOfferings()
            await subscriptionManager.refreshCustomerInfo()
        }
        .onChange(of: subscriptionManager.lastErrorMessage) { _, message in
            errorText = message
        }
        .alert("Subscription Error", isPresented: Binding(get: {
            errorText != nil
        }, set: { value in
            if !value { errorText = nil }
        })) {
            Button("OK", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "Something went wrong. Please try again.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .shadow(color: Color.primaryYellow.opacity(0.34), radius: 18, x: 0, y: 0)

            Text("MultiFlow Pro")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("Unlock faster underwriting tools and deeper market intelligence.")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(red: 0.16, green: 0.16, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Text("M")
                    .font(.system(size: 58, weight: .black, design: .rounded))
                    .foregroundStyle(Color.primaryYellow)

                Text(subscriptionManager.selectedPlanSubtitle)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(displayPrice(for: subscriptionManager.selectedPlan))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.primaryYellow.opacity(0.88))

                Text("Includes 25 Insight Credits / month")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
            .padding(.vertical, 30)
        }
        .frame(height: 200)
        .rotation3DEffect(
            .degrees(Double(-dragOffset.height / 8)),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(dragOffset.width / 8)),
            axis: (x: 0, y: 1, z: 0)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = CGSize(
                        width: min(max(value.translation.width, -36), 36),
                        height: min(max(value.translation.height, -36), 36)
                    )
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                        dragOffset = .zero
                    }
                }
        )
    }

    private var creditsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Insight Credit Model")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(usageManager.snapshot.remainingCredits) left")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.primaryYellow)
            }

            Text("Markets 1 • Rent AVM 1 • Value AVM 1 • Deep Dive Records 2")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var planPicker: some View {
        Picker("Billing", selection: $subscriptionManager.selectedPlan) {
            ForEach(SubscriptionManager.BillingPlan.allCases) { plan in
                Text(planPickerLabel(for: plan)).tag(plan)
            }
        }
        .pickerStyle(.segmented)
        .tint(Color.primaryYellow)
    }

    private var benefitsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(features) { feature in
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primaryYellow)

                    Text(feature.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)

                    Text(feature.caption)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var mainCTA: some View {
        Button {
            Task {
                let didUnlock = await subscriptionManager.purchaseSelectedPlan()
                if didUnlock { dismiss() }
            }
        } label: {
            HStack(spacing: 8) {
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.richBlack)
                }
                Text("Start 7-Day Free Trial")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.richBlack)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primaryYellow)
            )
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isPurchasing)
        .opacity(subscriptionManager.isPurchasing ? 0.8 : 1)
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                legalLinkButton("Restore Purchases") {
                    Task {
                        let didUnlock = await subscriptionManager.restorePurchases()
                        if didUnlock { dismiss() }
                    }
                }
                legalLinkButton("Terms of Service") {
                    openExternal("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                }
                legalLinkButton("Privacy Policy") {
                    openExternal("https://www.revenuecat.com/privacy")
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))

            Text("Cancel anytime during trial. Billing starts after trial ends.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.36))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private func legalLinkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .foregroundStyle(Color.white.opacity(0.45))
    }

    private func openExternal(_ value: String) {
        guard let url = URL(string: value) else { return }
        UIApplication.shared.open(url)
    }

    private func displayPrice(for plan: SubscriptionManager.BillingPlan) -> String {
        switch plan {
        case .monthly:
            return "$10/month"
        case .annual:
            return "$150/year"
        }
    }

    private func planPickerLabel(for plan: SubscriptionManager.BillingPlan) -> String {
        switch plan {
        case .monthly:
            return "Monthly · $10"
        case .annual:
            return "Annual · $150"
        }
    }
}

struct PaywallView: View {
    var body: some View {
        PremiumPaywallView()
    }
}

#Preview {
    PremiumPaywallView()
        .environmentObject(SubscriptionManager())
}
