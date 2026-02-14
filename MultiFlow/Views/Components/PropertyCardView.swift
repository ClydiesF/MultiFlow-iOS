import SwiftUI
import UIKit

struct PropertyCardView: View {
    @EnvironmentObject private var gradeProfileStore: GradeProfileStore
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    let property: Property
    var onUpdateStrategy: ((Double) -> Void)? = nil
    var onOpenDetail: (() -> Void)? = nil

    @State private var isFlipped = false
    @State private var targetDCR = 1.25

    private let backColor = Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 18.0 / 255.0)
    private let flipAnimation = Animation.spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.15)

    var body: some View {
        ZStack {
            frontCard
                .rotation3DEffect(
                    .degrees(isFlipped ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.8
                )
                .opacity(isFlipped ? 0 : 1)

            backCard
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.8
                )
                .opacity(isFlipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 325)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onOpenDetail?()
        }
        .gesture(flipGesture)
        .onChange(of: isFlipped) { _, _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                generator.impactOccurred(intensity: 0.9)
            }
        }
    }

    private var flipGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let threshold: CGFloat = 56
                if value.translation.width <= -threshold, !isFlipped {
                    withAnimation(flipAnimation) {
                        isFlipped = true
                    }
                } else if value.translation.width >= threshold, isFlipped {
                    withAnimation(flipAnimation) {
                        isFlipped = false
                    }
                }
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
                .frame(height: 196)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )

                gradeBadge
                    .padding(14)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if property.isProvisionalEstimate {
                        Text("Estimate")
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.primaryYellow.opacity(0.88))
                            )
                    }

                    ownershipChip

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: activeProfile.colorHex))
                            .frame(width: 8, height: 8)
                        Text(activeProfile.name)
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.58))
                    )
                }
                .padding(14)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(property.address)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack)
                    .lineLimit(2)

                if !locationLine.isEmpty {
                    Text(locationLine)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                        .lineLimit(1)
                }

                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Price")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.55))
                        Text(currencyString(property.purchasePrice))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.richBlack)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Monthly Cash Flow")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.55))
                        Text(currencyString(monthlyCashFlow))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(monthlyCashFlow >= 0 ? Color.richBlack : Color.red.opacity(0.9))
                    }
                }
            }
            .padding(16)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 12)
        )
    }

    private var backCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Target DCR")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Spacer()
                    Text(String(format: "%.2f", targetDCR))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.primaryYellow)
                }

                Slider(value: $targetDCR, in: 1.10...1.50, step: 0.01)
                    .tint(Color.primaryYellow)

                HStack {
                    Text("1.10")
                    Spacer()
                    Text("1.50")
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Maximum Allowable Offer")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(maxAllowableOfferText)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 215.0 / 255.0, blue: 0.0))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: maxAllowableOfferValue)
            }

            proofOfMathGrid

            Spacer(minLength: 0)

            Button {
                guard let offer = maxAllowableOfferValue else { return }
                onUpdateStrategy?(offer)
            } label: {
                HStack {
                    Spacer()
                    Text("Update Strategy")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Spacer()
                }
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.black)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 1.0, green: 215.0 / 255.0, blue: 0.0))
            )
            .disabled(maxAllowableOfferValue == nil)
            .opacity(maxAllowableOfferValue == nil ? 0.45 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backColor)
                .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 16)
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

    private var maxAllowableOfferValue: Double? {
        MFMetricEngine.maximumAllowableOffer(for: property, targetDCR: targetDCR)
    }

    private var maxAllowableOfferText: String {
        guard let offer = maxAllowableOfferValue else {
            return "—"
        }
        return currencyString(offer)
    }

    private var proofOfMathGrid: some View {
        HStack(spacing: 12) {
            proofCell(
                title: "NOI",
                value: currencyString(metrics?.netOperatingIncome ?? 0)
            )
            proofCell(
                title: "Loan Amount",
                value: currencyString(loanAmount)
            )
        }
    }

    private func proofCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
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

    private var metrics: DealMetrics? {
        MetricsEngine.computeMetrics(property: property)
    }

    private var loanAmount: Double {
        guard let downPaymentPercent = property.downPaymentPercent else { return 0 }
        return max(property.purchasePrice * (1.0 - downPaymentPercent / 100.0), 0)
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
