import SwiftUI

struct PropertyCardView: View {
    @EnvironmentObject private var gradeProfileStore: GradeProfileStore
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0
    let property: Property
    var onOpenDetail: (() -> Void)? = nil
    var heroNamespace: Namespace.ID? = nil
    var heroID: String? = nil

    var body: some View {
        Group {
            if let heroNamespace, let heroID {
                frontCard
                    .matchedGeometryEffect(id: heroID, in: heroNamespace)
            } else {
                frontCard
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: hasPropertyImage ? 232 : 168)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(statusStripColor)
                    .frame(width: 5)
                    .padding(.vertical, 8)
            }
        .onTapGesture {
            onOpenDetail?()
        }
    }

    private var frontCard: some View {
        VStack(spacing: 0) {
            if hasPropertyImage {
                ZStack(alignment: .topTrailing) {
                    DownsampledRemoteImageView(
                        urlString: property.imageURL,
                        maxPixelSize: 960,
                        contentMode: .fill
                    ) {
                        Color.softGray
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 112)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )

                    VStack(alignment: .trailing, spacing: 6) {
                        gradeBadge
                        if shouldShowMarketAlert {
                            marketAlertBadge
                        }
                        occupancyGrid
                    }
                    .padding(10)
                }

                .overlay(alignment: .topLeading) {
                    statusChips
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if !hasPropertyImage {
                    HStack {
                        statusChips
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            gradeBadge
                            if shouldShowMarketAlert {
                                marketAlertBadge
                            }
                            occupancyGrid
                        }
                    }
                    .padding(.bottom, 2)
                }

                Text(property.address)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack)
                    .lineLimit(1)

                if !locationLine.isEmpty {
                    Text(locationLine)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                        .lineLimit(1)
                }

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.55))
                        Text(currencyString(property.purchasePrice))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.richBlack)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Monthly Cash Flow")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.55))
                        Text(currencyString(monthlyCashFlow))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(monthlyCashFlow >= 0 ? Color.green.opacity(0.9) : Color.red.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, hasPropertyImage ? 10 : 8)
            .padding(.bottom, 12)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cardSurface,
                            Color.cardSurface.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.primaryYellow.opacity(0.32),
                            Color.richBlack.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var gradeBadge: some View {
        GradeCircleView(grade: currentGrade)
            .frame(width: 42, height: 42)
            .scaleEffect(0.7)
    }

    private var marketAlertBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 10, weight: .bold))
            Text("Alert")
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.primaryYellow)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.richBlack.opacity(0.80))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primaryYellow.opacity(0.54), lineWidth: 1)
        )
        .shadow(color: Color.primaryYellow.opacity(0.22), radius: 6, x: 0, y: 2)
        .accessibilityLabel("Market alert")
    }

    private var occupancyGrid: some View {
        VStack(alignment: .trailing, spacing: 3) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    occupancyDot(index: 0)
                    occupancyDot(index: 1)
                }
                HStack(spacing: 4) {
                    occupancyDot(index: 2)
                    occupancyDot(index: 3)
                }
            }
            .padding(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.richBlack.opacity(0.68))
            )

            if property.rentRoll.count > 4 {
                Text("+\(property.rentRoll.count - 4)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .accessibilityLabel("\(leasedDoorCount) of \(max(property.rentRoll.count, 1)) doors leased")
    }

    private func occupancyDot(index: Int) -> some View {
        let activeDoors = min(max(property.rentRoll.count, 1), 4)
        let isActiveDoor = index < activeDoors
        let isLeasedDoor = index < filledDoorCount

        return Circle()
            .fill(
                isLeasedDoor
                ? Color.primaryYellow
                : (isActiveDoor ? Color.white.opacity(0.35) : Color.white.opacity(0.12))
            )
            .frame(width: 7, height: 7)
    }

    private var propertyImageURL: URL? {
        guard !property.imageURL.isEmpty else { return nil }
        return URL(string: property.imageURL)
    }

    private var ownershipChip: some View {
        let isOwned = property.isOwned == true
        return HStack(spacing: 6) {
            Image(systemName: isOwned ? "checkmark.seal.fill" : "clock")
                .font(.system(size: 10, weight: .bold))
            Text(isOwned ? "Owned" : "Prospective")
                .font(.system(.caption2, design: .rounded).weight(.bold))
        }
        .foregroundStyle(isOwned ? Color.richBlack : Color.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isOwned ? Color.primaryYellow.opacity(0.78) : Color.richBlack.opacity(0.66))
        )
    }

    private var hasPropertyImage: Bool { propertyImageURL != nil }

    private var statusStripColor: Color {
        property.isOwned == true ? Color.primaryYellow : Color.softGray.opacity(0.85)
    }

    private var statusChips: some View {
        HStack(spacing: 8) {
            if property.isProvisionalEstimate {
                Text("Estimate")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow.opacity(0.88))
                    )
            }
            ownershipChip
            profileChip
        }
    }

    private var profileChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: activeProfile.colorHex))
                .frame(width: 7, height: 7)
            Text(activeProfile.name)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(Color.white.opacity(0.94))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.richBlack.opacity(0.62))
        )
    }

    private var monthlyCashFlow: Double {
        guard let metrics = MetricsEngine.computeMetrics(property: property) else { return 0 }
        return metrics.annualCashFlow / 12.0
    }

    private var averageCurrentRent: Double {
        guard !property.rentRoll.isEmpty else { return 0 }
        let total = property.rentRoll.reduce(0) { $0 + $1.monthlyRent }
        return total / Double(property.rentRoll.count)
    }

    private var marketRentEstimate: Double {
        defaultMonthlyRentPerUnit
    }

    private var shouldShowMarketAlert: Bool {
        averageCurrentRent > 0 && averageCurrentRent < marketRentEstimate
    }

    private var leasedDoorCount: Int {
        property.rentRoll.filter { unit in
            unit.isLeased ?? (unit.monthlyRent > 0)
        }.count
    }

    private var filledDoorCount: Int {
        min(leasedDoorCount, 4)
    }

    private var currentGrade: Grade {
        guard let metrics = MetricsEngine.computeMetrics(property: property),
              let downPayment = property.downPaymentPercent,
              let interestRate = property.interestRate,
              let breakdown = MetricsEngine.mortgageBreakdown(
                purchasePrice: property.purchasePrice,
                downPaymentPercent: downPayment,
                interestRate: interestRate,
                loanTermYears: Double(property.loanTermYears ?? 30),
                annualTaxes: property.annualTaxes ?? (property.annualTaxesInsurance ?? 0),
                annualInsurance: property.annualInsurance ?? 0
              ) else {
            return MetricsEngine.computeMetrics(property: property)?.grade ?? .dOrF
        }

        let profile = gradeProfileStore.effectiveProfile(for: property)
        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: property.purchasePrice,
            unitCount: max(property.rentRoll.count, 1),
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: property.appreciationRate ?? 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private var activeProfile: GradeProfile {
        gradeProfileStore.effectiveProfile(for: property)
    }

    private var locationLine: String {
        let city = (property.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let state = (property.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let zip = (property.zipCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch (city.isEmpty, state.isEmpty, zip.isEmpty) {
        case (false, false, false):
            return "\(city), \(state) \(zip)"
        case (false, false, true):
            return "\(city), \(state)"
        case (false, true, false):
            return "\(city) \(zip)"
        case (true, false, false):
            return "\(state) \(zip)"
        case (false, true, true):
            return city
        case (true, false, true):
            return state
        case (true, true, false):
            return zip
        case (true, true, true):
            return ""
        }
    }

    private func currencyString(_ value: Double) -> String {
        Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }

}

#Preview {
    PropertyCardView(
        property: Property(
            address: "7813 Mission Ridge Ave",
            city: "Dallas",
            state: "TX",
            zipCode: "75001",
            imageURL: "https://images.unsplash.com/photo-1564013799919-ab600027ffc6",
            purchasePrice: 1_250_000,
            rentRoll: [
                RentUnit(monthlyRent: 2400, unitType: "2BR", bedrooms: 2, bathrooms: 1),
                RentUnit(monthlyRent: 2450, unitType: "2BR", bedrooms: 2, bathrooms: 2),
                RentUnit(monthlyRent: 1980, unitType: "1BR", bedrooms: 1, bathrooms: 1)
            ],
            useStandardOperatingExpense: true,
            operatingExpenseRate: 35,
            annualTaxes: 15_000,
            annualInsurance: 7_500,
            loanTermYears: 30,
            downPaymentPercent: 25,
            interestRate: 6.4
        )
    )
    .padding()
    .background(Color.canvasWhite)
    .environmentObject(GradeProfileStore())
}
