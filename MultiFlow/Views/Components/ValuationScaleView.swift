import SwiftUI

struct ValuationScaleView: View {
    struct ComparableSnapshot: Identifiable, Hashable, Codable {
        let id: UUID
        let title: String
        let address: String
        let estimate: Double
        let bedrooms: Int
        let bathrooms: Double
        let squareFeet: Int?
        let daysOnMarket: Int

        init(
            id: UUID = UUID(),
            title: String,
            address: String,
            estimate: Double,
            bedrooms: Int,
            bathrooms: Double,
            squareFeet: Int?,
            daysOnMarket: Int
        ) {
            self.id = id
            self.title = title
            self.address = address
            self.estimate = estimate
            self.bedrooms = bedrooms
            self.bathrooms = bathrooms
            self.squareFeet = squareFeet
            self.daysOnMarket = daysOnMarket
        }
    }

    let estimate: Double
    let rangeMin: Double
    let rangeMax: Double
    let comparables: [ComparableSnapshot]
    var onTapComparable: (ComparableSnapshot) -> Void = { _ in }

    private var normalizedRangeMin: Double { min(rangeMin, rangeMax) }
    private var normalizedRangeMax: Double { max(rangeMin, rangeMax) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Valuation Scale")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
                Spacer()
                Text(shortCurrency(estimate))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primaryYellow)
            }

            compactScale

            HStack {
                Text("Comparables")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                Spacer()
                Text("\(comparables.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            compRow
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardStroke)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var compactScale: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let domain = max(normalizedRangeMax - normalizedRangeMin, 1)
                let clampedEstimate = min(max(estimate, normalizedRangeMin), normalizedRangeMax)
                let markerX = ((clampedEstimate - normalizedRangeMin) / domain) * width

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 5)

                    Circle()
                        .fill(Color.primaryYellow)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
                        )
                        .shadow(color: Color.primaryYellow.opacity(0.4), radius: 5, x: 0, y: 2)
                        .offset(x: markerX - 7)
                }
                .frame(height: 14, alignment: .center)
            }
            .frame(height: 14)

            HStack {
                Text(shortCurrency(normalizedRangeMin))
                Spacer()
                Text(shortCurrency(normalizedRangeMax))
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    private var compRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(comparables) { comp in
                    Button {
                        onTapComparable(comp)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(comp.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.88))
                            Text(shortCurrency(comp.estimate))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.primaryYellow)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(comp.title), \(shortCurrency(comp.estimate))")
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.primaryYellow.opacity(0.14), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private func shortCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        let prefix = value < 0 ? "-" : ""
        if absValue >= 1_000_000 {
            return String(format: "\(prefix)$%.1fM", absValue / 1_000_000)
        }
        if absValue >= 1_000 {
            return String(format: "\(prefix)$%.0fk", absValue / 1_000)
        }
        return String(format: "\(prefix)$%.0f", absValue)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        ValuationScaleView(
            estimate: 425_000,
            rangeMin: 390_000,
            rangeMax: 455_000,
            comparables: [
                .init(title: "Comp A", address: "101 Oak St", estimate: 401_000, bedrooms: 3, bathrooms: 2, squareFeet: 1420, daysOnMarket: 11),
                .init(title: "Comp B", address: "221 Pine Ave", estimate: 412_000, bedrooms: 3, bathrooms: 2, squareFeet: 1510, daysOnMarket: 14),
                .init(title: "Comp C", address: "77 Cedar Ct", estimate: 438_000, bedrooms: 4, bathrooms: 3, squareFeet: 1880, daysOnMarket: 9)
            ]
        )
        .padding(20)
    }
}
