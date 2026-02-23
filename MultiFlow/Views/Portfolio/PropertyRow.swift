import SwiftUI

struct PropertyRow: View {
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    let property: Property

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                DownsampledRemoteImageView(
                    urlString: property.imageURL,
                    maxPixelSize: 960,
                    contentMode: .fill
                ) {
                    Color.softGray
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )

                gradePill
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(property.address)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    UnitTypeBadge(unitCount: property.rentRoll.count)
                    Circle()
                        .fill(Color(hex: activeProfile.colorHex))
                        .frame(width: 8, height: 8)
                    Text(activeProfile.name)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
                
                if let city = property.city, let state = property.state, let zip = property.zipCode,
                   !city.isEmpty, !state.isEmpty, !zip.isEmpty {
                    Text("\(city), \(state) \(zip)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }

                if totalBeds > 0 || totalBaths > 0 {
                    let bedsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBeds)) ?? "\(totalBeds)"
                    let bathsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBaths)) ?? "\(totalBaths)"
                    Text("\(bedsText) Beds • \(bathsText) Baths")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )

        .overlay(alignment: .bottomTrailing) {
            cashflowSeal
                .padding(12)
        }
        .listRowBackground(Color.clear)
    }

    private var gradePill: some View {
        let color = Color(hex: activeProfile.colorHex)
        return Text(grade.rawValue)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.9))
            )
    }

    private var cashflowSeal: some View {
        let met = cashflowPillarMet
        let fill = met ? Color.primaryYellow : Color.softGray
        let iconColor = met ? Color.richBlack : Color.richBlack.opacity(0.5)
        return ZStack {
            Circle()
                .fill(fill)
                .frame(width: 34, height: 34)
            Circle()
                .stroke(Color.richBlack.opacity(0.15), lineWidth: 2)
                .frame(width: 34, height: 34)
            Image(systemName: "dollarsign")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconColor)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
    }

    private var cashflowPillarMet: Bool {
        guard let metrics = MetricsEngine.computeMetrics(property: property) else { return false }
        let monthlyCashFlow = metrics.annualCashFlow / 12.0
        return monthlyCashFlow >= cashflowBreakEvenThreshold
    }

    private var grade: Grade {
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

    private var totalBeds: Double {
        property.rentRoll.reduce(0) { $0 + $1.bedrooms }
    }

    private var totalBaths: Double {
        property.rentRoll.reduce(0) { $0 + $1.bathrooms }
    }
}

#Preview {
    PropertyRow(property: Property(
        address: "123 Lakeshore Blvd",
        imageURL: "",
        purchasePrice: 1200000,
        rentRoll: [
            RentUnit(monthlyRent: 1800, unitType: "2BR", bedrooms: 2, bathrooms: 1),
            RentUnit(monthlyRent: 1900, unitType: "2BR", bedrooms: 2, bathrooms: 1.5)
        ],
        annualTaxes: 16000,
        annualInsurance: 8000,
        loanTermYears: 30,
        downPaymentPercent: 25,
        interestRate: 6.2
    ))
    .padding()
    .environmentObject(GradeProfileStore())
}
