import SwiftUI
import UIKit
import Charts

struct PortfolioView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @State private var showingAdd = false
    @State private var showToast = false
    @State private var showDeleteToast = false
    @State private var lastDeletedProperty: Property?
    @State private var deleteToastTask: Task<Void, Never>?
    @State private var showRestoreErrorToast = false
    @State private var restoreErrorMessage: String?
    @State private var selectedPropertyForDetail: Property?

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header

                    portfolioSummarySection
                    summaryDivider
                    if propertyStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if propertyStore.properties.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 34) {
                            ForEach(propertyStore.properties) { property in
                                PropertyCardView(property: property) { updatedOffer in
                                    saveStrategyOffer(updatedOffer, for: property)
                                } onOpenDetail: {
                                    selectedPropertyForDetail = property
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
                .padding(24)
            }

            if showToast || showDeleteToast || showRestoreErrorToast {
                VStack(spacing: 8) {
                    if showToast {
                        successToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showDeleteToast {
                        deleteToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if showRestoreErrorToast {
                        restoreErrorToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPropertyForDetail) { property in
            PropertyDetailView(property: property)
                .environmentObject(propertyStore)
                .environmentObject(gradeProfileStore)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26)
                    .accessibilityHidden(true)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    GradeProfilesView()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Grade profiles")

                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd, onDismiss: {
            propertyStore.listen()
        }) {
            AddPropertySheet(didAddProperty: $showToast)
                .environmentObject(propertyStore)
                .environmentObject(gradeProfileStore)
        }
        .onChange(of: propertyStore.lastDeletedProperty) { _, newValue in
            guard let deleted = newValue else { return }
            lastDeletedProperty = deleted
            triggerDeleteHaptic()
            Task {
                try? await Task.sleep(nanoseconds: 150_000_000)
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showDeleteToast = true
                    }
                }
            }
            scheduleDeleteToastDismiss()
        }
        .onChange(of: showToast) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    withAnimation(.easeOut(duration: 0.2)) {
                        showToast = false
                    }
                }
            }
        }
        .onAppear {
            propertyStore.listen()
        }
        .onDisappear {
            propertyStore.stopListening()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No properties yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            Text("Add your first multifamily deal to start tracking grades and metrics.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Add Property") {
                showingAdd = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }

    private var portfolioSummarySection: some View {
        let metrics = portfolioMetrics
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PortfolioMetricTile(title: "Properties", value: String(metrics.propertyCount))
                PortfolioMetricTile(title: "Doors", value: String(metrics.totalDoors))
                PortfolioMetricTile(title: "Portfolio Value", value: Formatters.currencyTwo.string(from: NSNumber(value: metrics.totalValue)) ?? "$0")
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 0)
        }
    }

    private var portfolioMetrics: PortfolioMetrics {
        let properties = propertyStore.properties
        let ownedProperties = properties.filter { $0.isOwned == true }
        let totalValue = ownedProperties.reduce(0) { $0 + $1.purchasePrice }
        let totalDoors = ownedProperties.reduce(0) { $0 + $1.rentRoll.count }

        return PortfolioMetrics(
            propertyCount: ownedProperties.count,
            totalDoors: totalDoors,
            totalValue: totalValue
        )
    }

    private var cashFlowHealth: CashFlowHealth {
        let properties = propertyStore.properties
        var positive = 0
        var breakEven = 0
        var negative = 0

        for property in properties {
            guard let metrics = MetricsEngine.computeMetrics(property: property) else { continue }
            let monthly = metrics.annualCashFlow / 12.0
            if abs(monthly) < cashflowBreakEvenThreshold {
                breakEven += 1
            } else if monthly > 0 {
                positive += 1
            } else {
                negative += 1
            }
        }

        return CashFlowHealth(positive: positive, breakEven: breakEven, negative: negative)
    }

    private var summaryDivider: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.primaryYellow)
                .frame(width: 132, height: 6)
            Rectangle()
                .fill(Color.richBlack.opacity(0.08))
                .frame(height: 1)
            Capsule()
                .fill(Color.primaryYellow.opacity(0.4))
                .frame(width: 78, height: 4)
        }
        .padding(.vertical, 6)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Portfolio")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("Your graded multifamily pipeline.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Track. Compare. Improve.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var successToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.primaryYellow)
            Text("Property added to portfolio")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private var deleteToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
                .foregroundStyle(Color.richBlack.opacity(0.7))
            Text("Property deleted")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Spacer()
            Button("Undo") {
                Task { await undoDelete() }
            }
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primaryYellow)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private var restoreErrorToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.richBlack.opacity(0.7))
            Text(restoreErrorMessage ?? "Unable to restore property")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private func saveStrategyOffer(_ offer: Double, for property: Property) {
        guard let index = propertyStore.properties.firstIndex(where: { $0.id == property.id }) else { return }
        propertyStore.properties[index].suggestedOfferPrice = offer
        let updatedProperty = propertyStore.properties[index]

        Task {
            do {
                try await propertyStore.updateProperty(updatedProperty)
            } catch {
                await MainActor.run {
                    restoreErrorMessage = "Failed to save strategy: \(error.localizedDescription)"
                    withAnimation(.easeOut(duration: 0.25)) {
                        showRestoreErrorToast = true
                    }
                }
            }
        }
    }

    private func triggerDeleteHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func scheduleDeleteToastDismiss() {
        deleteToastTask?.cancel()
        deleteToastTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.5)) {
                    showDeleteToast = false
                }
                propertyStore.clearLastDeleted()
                lastDeletedProperty = nil
            }
        }
    }

    private func scheduleRestoreErrorDismiss() {
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    showRestoreErrorToast = false
                }
                restoreErrorMessage = nil
            }
        }
    }

    private func undoDelete() async {
        guard let property = lastDeletedProperty else { return }
        deleteToastTask?.cancel()
        do {
            try await propertyStore.restoreProperty(property)
        } catch {
            await MainActor.run {
                restoreErrorMessage = error.localizedDescription
                withAnimation(.easeOut(duration: 0.5)) {
                    showRestoreErrorToast = true
                }
                scheduleRestoreErrorDismiss()
            }
        }
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.5)) {
                showDeleteToast = false
            }
            propertyStore.clearLastDeleted()
            lastDeletedProperty = nil
        }
    }

}


struct PortfolioMetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 44, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
    }
}



struct PortfolioMetrics {
    let propertyCount: Int
    let totalDoors: Int
    let totalValue: Double
}

struct CashFlowHealth {
    let positive: Int
    let breakEven: Int
    let negative: Int
}


#Preview {
    NavigationStack {
        PortfolioView()
            .environmentObject(PropertyStore())
            .environmentObject(GradeProfileStore())
    }
}
