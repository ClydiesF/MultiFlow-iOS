import SwiftUI

struct MarketInsightView: View {
    let snapshot: MarketInsightSnapshot?
    let isPremiumUnlocked: Bool
    let isLoading: Bool
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Market Insights")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Text("Pro")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow.opacity(0.85))
                    )
            }

            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        insightCard(
                            title: "Rent Growth",
                            value: snapshot?.formattedRentGrowth ?? "—",
                            valueColor: ((snapshot?.rentGrowthYoYPercent ?? 0) >= 0) ? Color.primaryYellow : Color.red.opacity(0.85)
                        )
                        insightCard(
                            title: "Days on Market",
                            value: snapshot?.formattedDaysOnMarket ?? "—",
                            valueColor: Color.richBlack
                        )
                        insightCard(
                            title: "Inventory Level",
                            value: snapshot?.inventoryLevel ?? "—",
                            valueColor: Color.richBlack
                        )
                    }
                    .padding(.vertical, 2)
                }
                .blur(radius: isPremiumUnlocked ? 0 : 6)
                .overlay {
                    if isLoading {
                        ProgressView()
                    }
                }

                if !isPremiumUnlocked {
                    VStack(spacing: 10) {
                        Text("Unlock Market Insights")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                        Button(action: onUnlock) {
                            Text("Unlock Market Insights")
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.richBlack)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.primaryYellow)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cardSurface.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 6)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.softGray)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
        )
    }

    private func insightCard(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(width: 155, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.richBlack.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    MarketInsightView(
        snapshot: MarketInsightSnapshot(rentGrowthYoYPercent: 5.2, daysOnMarket: 18, inventoryLevel: "Tight"),
        isPremiumUnlocked: false,
        isLoading: false,
        onUnlock: {}
    )
    .padding()
}
