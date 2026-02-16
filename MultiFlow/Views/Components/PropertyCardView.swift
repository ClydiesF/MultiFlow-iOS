import SwiftUI

struct PropertyCardView: View {
    @EnvironmentObject private var gradeProfileStore: GradeProfileStore
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    let property: Property
    var onOpenDetail: (() -> Void)? = nil

    var body: some View {
        frontCard
            .frame(maxWidth: .infinity)
            .frame(height: 232)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            onOpenDetail?()
        }
    }

    private var frontCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: propertyImageURL) { phase in
                    switch phase {
                    case .empty:
                        propertyImagePlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        propertyImagePlaceholder
                    @unknown default:
                        propertyImagePlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .clipShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                gradeBadge
                    .padding(10)
            }
            .overlay(alignment: .topLeading) {
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
                }
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
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

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: activeProfile.colorHex))
                        .frame(width: 8, height: 8)
                    Text(activeProfile.name)
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
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
                            .foregroundStyle(monthlyCashFlow >= 0 ? Color.richBlack : Color.red.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
        )
    }

    private var gradeBadge: some View {
        GradeCircleView(grade: currentGrade)
            .frame(width: 42, height: 42)
            .scaleEffect(0.7)
    }

    private var propertyImageURL: URL? {
        guard !property.imageURL.isEmpty else { return nil }
        return URL(string: property.imageURL)
    }

    private var ownershipChip: some View {
        let isOwned = property.isOwned == true
        return HStack(spacing: 6) {
            Image(systemName: isOwned ? "checkmark.seal.fill" : "clock.badge.exclamationmark")
                .font(.system(size: 10, weight: .bold))
            Text(isOwned ? "Owned" : "Prospective")
                .font(.system(.caption2, design: .rounded).weight(.bold))
        }
        .foregroundStyle(Color.white.opacity(0.94))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isOwned ? Color.green.opacity(0.75) : Color.richBlack.opacity(0.58))
        )
    }

    private var propertyImagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.softGray, Color.cardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.55))
                Text("No Photo")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.52))
            }
        }
    }

    private var monthlyCashFlow: Double {
        guard let metrics = MetricsEngine.computeMetrics(property: property) else { return 0 }
        return metrics.annualCashFlow / 12.0
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
