import SwiftUI
import UIKit
import Charts

struct PortfolioView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @State private var showingAdd = false
    @State private var showingPaywall = false
    @State private var showToast = false
    @State private var showDeleteToast = false
    @State private var lastDeletedProperty: Property?
    @State private var deleteToastTask: Task<Void, Never>?
    @State private var showRestoreErrorToast = false
    @State private var restoreErrorMessage: String?
    @State private var selectedPropertyForDetail: Property?
    @State private var isShowingPropertyDetail = false
    @State private var sortOption: PortfolioSortOption = .recency
    @AppStorage("portfolioTrendBaselineMonthKey") private var trendBaselineMonthKey = ""
    @AppStorage("portfolioTrendBaselinePropertyCount") private var trendBaselinePropertyCount = 0
    @AppStorage("portfolioTrendBaselineDoors") private var trendBaselineDoors = 0
    @AppStorage("portfolioTrendBaselineValue") private var trendBaselineValue = 0.0
    @Namespace private var cardHeroNamespace

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
                        LazyVStack(spacing: 30) {
                            ForEach(sortedProperties) { property in
                                PropertyCardView(
                                    property: property,
                                    onOpenDetail: {
                                        selectedPropertyForDetail = property
                                        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                                            isShowingPropertyDetail = true
                                        }
                                    },
                                    heroNamespace: cardHeroNamespace,
                                    heroID: cardHeroID(for: property)
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        selectedPropertyForDetail = property
                                        withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                                            isShowingPropertyDetail = true
                                        }
                                    } label: {
                                        Label("Analyze", systemImage: "waveform.path.ecg")
                                    }
                                    .tint(Color.primaryYellow)

                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await propertyStore.deleteProperty(property)
                                            } catch {
                                                await MainActor.run {
                                                    restoreErrorMessage = error.localizedDescription
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        showRestoreErrorToast = true
                                                    }
                                                    scheduleRestoreErrorDismiss()
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                        .padding(.top, 10)
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

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fabAddButton
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 25)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingPropertyDetail) {
            if let property = selectedPropertyForDetail {
                PropertyDetailView(
                    property: property,
                    cardHeroNamespace: cardHeroNamespace,
                    cardHeroID: cardHeroID(for: property)
                )
                    .environmentObject(propertyStore)
                    .environmentObject(gradeProfileStore)
                    .environmentObject(subscriptionManager)
            } else {
                EmptyView()
            }
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

                Menu {
                    Button {
                        sortOption = .roi
                    } label: {
                        Label("ROI", systemImage: sortOption == .roi ? "checkmark" : "percent")
                    }

                    Button {
                        sortOption = .cashFlow
                    } label: {
                        Label("Cash Flow", systemImage: sortOption == .cashFlow ? "checkmark" : "dollarsign.circle")
                    }

                    Button {
                        sortOption = .recency
                    } label: {
                        Label("Recency", systemImage: sortOption == .recency ? "checkmark" : "clock")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter and sort properties")
            }
        }
        .sheet(isPresented: $showingAdd, onDismiss: {
            propertyStore.listen()
        }) {
            AddPropertySheet(didAddProperty: $showToast)
                .environmentObject(propertyStore)
                .environmentObject(gradeProfileStore)
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
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
            refreshTrendBaselineIfNeeded()
            propertyStore.listen()
        }
        .onChange(of: propertyStore.properties) { _, _ in
            refreshTrendBaselineIfNeeded()
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
                presentAddPropertyFlow()
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
        let trends = portfolioTrends
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                PortfolioMetricTile(
                    title: "Properties",
                    value: String(metrics.propertyCount),
                    trend: trends.properties
                )
                PortfolioMetricTile(
                    title: "Doors",
                    value: String(metrics.totalDoors),
                    trend: trends.doors
                )
                PortfolioMetricTile(
                    title: "Portfolio Value",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.totalValue)) ?? "$0",
                    trend: trends.value
                )
            }
            .scrollTargetLayout()
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .padding(.horizontal, -24)
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

    private var sortedProperties: [Property] {
        let base = propertyStore.properties
        switch sortOption {
        case .recency:
            return base
        case .cashFlow:
            return base.sorted { lhs, rhs in
                let left = MetricsEngine.computeMetrics(property: lhs)?.annualCashFlow ?? 0
                let right = MetricsEngine.computeMetrics(property: rhs)?.annualCashFlow ?? 0
                return left > right
            }
        case .roi:
            return base.sorted { lhs, rhs in
                let left = MetricsEngine.computeMetrics(property: lhs)?.cashOnCash ?? 0
                let right = MetricsEngine.computeMetrics(property: rhs)?.cashOnCash ?? 0
                return left > right
            }
        }
    }

    private var portfolioTrends: PortfolioMetricTrends {
        let metrics = portfolioMetrics
        return PortfolioMetricTrends(
            properties: makeTrendLabel(current: Double(metrics.propertyCount), baseline: Double(trendBaselinePropertyCount)),
            doors: makeTrendLabel(current: Double(metrics.totalDoors), baseline: Double(trendBaselineDoors)),
            value: makeTrendLabel(current: metrics.totalValue, baseline: trendBaselineValue)
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

    private func refreshTrendBaselineIfNeeded() {
        let monthKey = currentMonthKey()
        guard trendBaselineMonthKey != monthKey else { return }
        let metrics = portfolioMetrics
        trendBaselineMonthKey = monthKey
        trendBaselinePropertyCount = metrics.propertyCount
        trendBaselineDoors = metrics.totalDoors
        trendBaselineValue = metrics.totalValue
    }

    private func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private func makeTrendLabel(current: Double, baseline: Double) -> PortfolioMetricTrend {
        let safeBaseline = baseline == 0 ? 1 : baseline
        let percent = ((current - baseline) / safeBaseline) * 100.0
        let isPositive = percent >= 0
        let symbol = isPositive ? "arrow.up.right" : "arrow.down.right"
        let formattedPercent = String(format: "%+.1f%% this month", percent)
        return PortfolioMetricTrend(symbol: symbol, text: formattedPercent, isPositive: isPositive)
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

    private var fabAddButton: some View {
        Button {
            presentAddPropertyFlow()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Color.richBlack)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(Color.primaryYellow)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add property")
    }

    private func cardHeroID(for property: Property) -> String {
        property.id ?? property.address
    }

    private func triggerDeleteHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func presentAddPropertyFlow() {
        if subscriptionManager.isPremium || propertyStore.properties.count < 3 {
            showingAdd = true
        } else {
            showingPaywall = true
        }
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
    let trend: PortfolioMetricTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            HStack(spacing: 4) {
                Image(systemName: trend.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(trend.isPositive ? Color.green : Color.red)
                Text(trend.text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle((trend.isPositive ? Color.green : Color.red).opacity(0.85))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 62, alignment: .leading)
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

struct PortfolioMetricTrend {
    let symbol: String
    let text: String
    let isPositive: Bool
}

struct PortfolioMetricTrends {
    let properties: PortfolioMetricTrend
    let doors: PortfolioMetricTrend
    let value: PortfolioMetricTrend
}

enum PortfolioSortOption {
    case roi
    case cashFlow
    case recency
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
            .environmentObject(SubscriptionManager())
    }
}
