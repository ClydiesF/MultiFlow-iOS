import SwiftUI
import UIKit

struct RentalMarketScaleView: View {
    struct RentalComparable: Identifiable, Hashable {
        let id: UUID
        let address: String
        let monthlyRent: Double
        let distanceMiles: Double

        init(id: UUID = UUID(), address: String, monthlyRent: Double, distanceMiles: Double) {
            self.id = id
            self.address = address
            self.monthlyRent = monthlyRent
            self.distanceMiles = distanceMiles
        }
    }

    let currentRent: Double
    let medianMarketRent: Double
    let daysOnMarket: Int
    let rentGrowthPercent: Double
    let comparables: [RentalComparable]
    let isPremiumUnlocked: Bool
    let onUnlock: () -> Void

    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanStep = 0
    @State private var isRevealed = false
    @State private var selectedComparable: RentalComparable?

    private let scanLabels = [
        "Connecting to rental feeds...",
        "Benchmarking unit comps...",
        "Projecting rent upside..."
    ]

    private var targetRent: Double {
        max(medianMarketRent * 1.12, medianMarketRent + 125)
    }

    private var upside: Double {
        max(targetRent - currentRent, 0)
    }

    private var minScale: Double {
        min(currentRent, medianMarketRent, targetRent) * 0.90
    }

    private var maxScale: Double {
        max(currentRent, medianMarketRent, targetRent) * 1.10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !isPremiumUnlocked {
                lockedState
            } else if isScanning {
                scanState
            } else {
                interactiveScale
                    .onTapGesture {
                        if !isRevealed {
                            startScan()
                        }
                    }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primaryYellow.opacity(0.14), lineWidth: 1)
        )
        .sheet(item: $selectedComparable) { comp in
            comparableSheet(comp)
                .presentationDetents([.height(260), .medium])
        }
    }

    private var header: some View {
        HStack {
            Text("Rental Market Scale")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Current \(Formatters.currency.string(from: NSNumber(value: currentRent)) ?? "$0")")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.72))
                Text("+\(Formatters.currency.string(from: NSNumber(value: upside)) ?? "$0")/mo")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primaryYellow)
                    .opacity(isRevealed ? 1 : 0.55)
            }
        }
    }

    private var lockedState: some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 6).clipShape(Capsule())
            Button(action: onUnlock) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Unlock Market Rent Scale")
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primaryYellow)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private var scanState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scanLabels[scanStep])
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.75))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.softGray)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: geo.size.width * scanProgress)
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 4)
    }

    private var interactiveScale: some View {
        VStack(alignment: .leading, spacing: 10) {
            scaleLine
            marketPulseRow
            compsRow
        }
        .opacity(isRevealed ? 1 : 0.90)
    }

    private var scaleLine: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let domain = max(maxScale - minScale, 1)
            let currentX = ((currentRent - minScale) / domain) * width
            let targetX = ((targetRent - minScale) / domain) * width
            let zoneWidth = width * 0.14

            VStack(spacing: 8) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.softGray.opacity(0.9))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primaryYellow.opacity(0.20))
                        .frame(width: zoneWidth, height: 12)
                        .offset(x: max(targetX - (zoneWidth / 2), 0))

                    Path { path in
                        let start = CGPoint(x: currentX, y: 3)
                        let end = CGPoint(x: targetX, y: 3)
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.primaryYellow.opacity(0.8))

                    Circle()
                        .fill(Color.primaryYellow)
                        .frame(width: 13, height: 13)
                        .shadow(color: Color.primaryYellow.opacity(0.58), radius: 8, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .fill(Color.primaryYellow.opacity(0.35))
                                .blur(radius: 4)
                                .frame(width: 20, height: 20)
                        )
                        .offset(x: currentX - 6.5)
                }
                .frame(height: 14, alignment: .center)

                HStack {
                    Text(fullCurrency(minScale))
                    Spacer()
                    Text(fullCurrency(maxScale))
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.65))
            }
        }
        .frame(height: 52)
    }

    private var marketPulseRow: some View {
        HStack(spacing: 8) {
            pulseChip(title: "Avg. Zip Rent", value: Formatters.currency.string(from: NSNumber(value: medianMarketRent)) ?? "$0")
            pulseChip(title: "DOM", value: "\(daysOnMarket)d")
            pulseChip(title: "Rent Growth", value: "\(rentGrowthPercent >= 0 ? "+" : "")\(String(format: "%.1f", rentGrowthPercent))%")
        }
    }

    private var compsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(comparables) { comp in
                    Button {
                        selectedComparable = comp
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(comp.address)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.richBlack)
                                .lineLimit(1)
                            Text("\(Formatters.currency.string(from: NSNumber(value: comp.monthlyRent)) ?? "$0") • \(String(format: "%.1f", comp.distanceMiles)) mi")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primaryYellow)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.softGray)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pulseChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.richBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func comparableSheet(_ comp: RentalComparable) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rental Comp")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text(comp.address)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.74))

            HStack(spacing: 10) {
                pulseChip(title: "Rent", value: Formatters.currency.string(from: NSNumber(value: comp.monthlyRent)) ?? "$0")
                pulseChip(title: "Distance", value: "\(String(format: "%.1f", comp.distanceMiles)) mi")
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CanvasBackground())
    }

    private func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanStep = 0

        let tick = 0.03
        let total = Int(1.8 / tick)
        Task {
            for step in 0...total {
                let fraction = min(Double(step) / Double(total), 1)
                await MainActor.run {
                    scanProgress = fraction
                    if fraction < 0.33 { scanStep = 0 }
                    else if fraction < 0.66 { scanStep = 1 }
                    else { scanStep = 2 }
                }
                try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
            }

            await MainActor.run {
                isScanning = false
                isRevealed = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func shortCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000 { return String(format: "$%.1fM", absValue / 1_000_000) }
        if absValue >= 1_000 { return String(format: "$%.0fk", absValue / 1_000) }
        return String(format: "$%.0f", absValue)
    }

    private func fullCurrency(_ value: Double) -> String {
        Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    RentalMarketScaleView(
        currentRent: 1450,
        medianMarketRent: 1710,
        daysOnMarket: 17,
        rentGrowthPercent: 5.4,
        comparables: [
            .init(address: "118 Amber Ln", monthlyRent: 1650, distanceMiles: 0.7),
            .init(address: "240 Ridge Rd", monthlyRent: 1750, distanceMiles: 1.2),
            .init(address: "75 Willow Dr", monthlyRent: 1825, distanceMiles: 1.9)
        ],
        isPremiumUnlocked: true,
        onUnlock: {}
    )
    .padding()
    .background(CanvasBackground())
}
