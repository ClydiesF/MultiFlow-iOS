import SwiftUI
import Charts
import UIKit

struct PropertyDeepDiveView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let property: Property

    @State private var scanState: IntelligenceScanState = .notRequested
    @State private var scanProgress: Double = 0
    @State private var scanStatusText: String = "Connecting to County Records..."
    @State private var showPaywall = false
    @State private var scanData: IntelligenceScanData?
    @State private var selectedComparable: ValuationScaleView.ComparableSnapshot?

    private let statusSteps = [
        "Connecting to County Records...",
        "Analyzing Tax Liens...",
        "Verifying Ownership..."
    ]
    private let offWhite = Color(white: 0.95)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Intelligence Scan")
                scanTriggerCard

                if scanState != .notRequested {
                    Section {
                        gatedCard(isLocked: !subscriptionManager.isPremium) {
                            ownershipContent
                        }
                    } header: {
                        sectionHeader("Ownership")
                    }

                    Section {
                        gatedCard(isLocked: !subscriptionManager.isPremium) {
                            taxHistoryContent
                        }
                    } header: {
                        sectionHeader("Tax History")
                    }

                    Section {
                        sectionCard {
                            valuationContent
                        }
                    } header: {
                        sectionHeader("Valuation Range")
                    }

                    Section {
                        sectionCard {
                            specsContent
                        }
                    } header: {
                        sectionHeader("Physical Specs")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(CanvasBackground())
        .navigationTitle("Property Deep Dive")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $selectedComparable) { comparable in
            ComparableDetailSheet(comparable: comparable)
                .presentationDetents([.height(300), .medium])
        }
    }

    private var scanTriggerCard: some View {
        sectionCard {
            VStack(alignment: .leading, spacing: 12) {
                if scanState == .notRequested {
                    VStack(alignment: .leading, spacing: 10) {
                        skeletonLine(width: 150, height: 12)
                        skeletonLine(width: 220, height: 11)
                        skeletonLine(width: 190, height: 11)
                    }
                    .redacted(reason: .placeholder)
                    .blur(radius: 2.5)

                    Button {
                        if subscriptionManager.isPremium {
                            Task { await performIntelligenceScan() }
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Text(subscriptionManager.isPremium ? "Perform Intelligence Scan" : "Unlock with Pro")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primaryYellow)
                            )
                    }
                    .buttonStyle(.plain)
                } else if scanState == .scanning {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(scanStatusText)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(offWhite)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primaryYellow)
                                    .frame(width: geo.size.width * scanProgress)
                            }
                        }
                        .frame(height: 10)

                        skeletonScanPlaceholders
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.primaryYellow)
                        Text("Intelligence Scan complete")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(offWhite)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
    }

    private var ownershipContent: some View {
        Group {
            if scanState == .scanning {
                skeletonOwnership
            } else if let data = scanData {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow("OwnerName", value: data.ownerName)
                    detailRow("MailingAddress", value: data.mailingAddress)
                    detailRow("LastSaleDate", value: data.lastSaleDate)
                    detailRow("Owner Occupied", value: data.isOwnerOccupied ? "Yes" : "No")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var taxHistoryContent: some View {
        Group {
            if scanState == .scanning {
                skeletonTaxChart
            } else if let data = scanData {
                VStack(alignment: .leading, spacing: 14) {
                    Chart(Array(data.taxHistory.enumerated()), id: \.element.year) { index, point in
                        let prior = index > 0 ? data.taxHistory[index - 1].taxAmount : nil
                        let isJump = isTaxJumpOverTenPercent(current: point.taxAmount, previous: prior)
                        BarMark(
                            x: .value("Assessment Year", point.year),
                            y: .value("Tax", point.taxAmount)
                        )
                        .foregroundStyle(isJump ? Color.red.opacity(0.92) : Color.primaryYellow)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) {
                            AxisValueLabel()
                                .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
                                .foregroundStyle(Color.white.opacity(0.16))
                            AxisValueLabel {
                                if let raw = value.as(Double.self) {
                                    Text(shortCurrency(raw))
                                }
                            }
                            .foregroundStyle(Color.white.opacity(0.72))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tax Assessment History")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.74))

                        ForEach(data.taxHistory) { point in
                            HStack {
                                Text(formattedYear(point.year))
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.7))
                                Spacer()
                                Text(currency(point.assessedValue))
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                                    .foregroundStyle(offWhite)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var specsContent: some View {
        Group {
            if scanState == .scanning {
                skeletonSpecsGrid
            } else if let data = scanData {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    specsTile(label: "YearBuilt", value: "\(data.yearBuilt)")
                    specsTile(label: "Floor Count", value: "\(data.floorCount)")
                    specsTile(label: "ZoningCode", value: data.zoningCode)
                    specsTile(label: "SquareFootage", value: "\(data.squareFootage) sq ft")
                    specsTile(label: "Lot Size", value: data.lotSize)
                    specsTile(label: "Units", value: "\(data.units)")
                    specsTile(label: "Subdivision", value: data.subdivision)
                    specsTile(label: "HOA", value: data.hasHOA ? "Yes" : "No")
                    specsTile(label: "Foundation", value: data.foundationType)
                    specsTile(label: "Cooling", value: data.coolingType)
                    specsTile(label: "Heating", value: data.heatingType)
                    specsTile(label: "Garage / Pool", value: "\(data.hasGarage ? "Garage" : "No Garage") • \(data.hasPool ? "Pool" : "No Pool")")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var valuationContent: some View {
        Group {
            if scanState == .scanning {
                skeletonTaxChart
            } else if let data = scanData {
                ValuationScaleView(
                    estimate: data.valuationEstimate,
                    rangeMin: data.valuationRangeMin,
                    rangeMax: data.valuationRangeMax,
                    comparables: data.comparables
                ) { comparable in
                    selectedComparable = comparable
                }
            }
        }
    }

    private var skeletonScanPlaceholders: some View {
        VStack(spacing: 8) {
            skeletonLine(width: .infinity, height: 10)
            skeletonLine(width: .infinity, height: 10)
            skeletonLine(width: .infinity, height: 10)
        }
    }

    private var skeletonOwnership: some View {
        VStack(spacing: 10) {
            skeletonLine(width: .infinity, height: 16)
            skeletonLine(width: .infinity, height: 16)
            skeletonLine(width: .infinity, height: 16)
        }
    }

    private var skeletonTaxChart: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(i == 2 ? Color.primaryYellow.opacity(0.35) : Color.white.opacity(0.15))
                    .frame(height: CGFloat(50 + (i * 18)))
                    .modifier(ShimmerEffect())
            }
        }
        .frame(height: 180, alignment: .bottom)
    }

    private var skeletonSpecsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(0..<12, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 62)
                    .modifier(ShimmerEffect())
            }
        }
    }

    @ViewBuilder
    private func gatedCard<Content: View>(isLocked: Bool, @ViewBuilder content: () -> Content) -> some View {
        sectionCard {
            content()
                .blur(radius: isLocked ? 4 : 0)
                .overlay {
                    if isLocked {
                        BlurredDataOverlay {
                            showPaywall = true
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primaryYellow)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.72))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(offWhite)
                .multilineTextAlignment(.trailing)
        }
    }

    private func specsTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.66))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(offWhite)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.12))
            .frame(maxWidth: width == .infinity ? .infinity : width)
            .frame(height: height)
            .modifier(ShimmerEffect())
    }

    private func shortCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.0fk", value / 1000.0)
        }
        return currency(value)
    }

    private func currency(_ value: Double) -> String {
        Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func formattedYear(_ year: Int) -> String {
        year.formatted(.number.grouping(.never))
    }

    private func isTaxJumpOverTenPercent(current: Double, previous: Double?) -> Bool {
        guard let previous, previous > 0 else { return false }
        return ((current - previous) / previous) > 0.10
    }

    @MainActor
    private func performIntelligenceScan() async {
        guard scanState != .scanning else { return }
        scanState = .scanning
        scanProgress = 0
        scanStatusText = statusSteps[0]

        let duration: Double = 1.8
        let tick: Double = 0.03
        let steps = Int(duration / tick)

        for step in 0...steps {
            let fraction = min(Double(step) / Double(steps), 1)
            scanProgress = fraction

            if fraction < 0.33 {
                scanStatusText = statusSteps[0]
            } else if fraction < 0.66 {
                scanStatusText = statusSteps[1]
            } else {
                scanStatusText = statusSteps[2]
            }

            try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
        }

        scanData = buildMockScanData()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            scanState = .loaded
        }
    }

    private func buildMockScanData() -> IntelligenceScanData {
        let currentYear = Calendar.current.component(.year, from: Date())
        let baseTax = property.annualTaxes ?? max(property.purchasePrice * 0.0223, 0)

        let taxHistory: [TaxYearPoint] = (0..<5).map { offset in
            let year = currentYear - (4 - offset)
            let multiplier: Double
            switch offset {
            case 0: multiplier = 0.86
            case 1: multiplier = 0.92
            case 2: multiplier = 1.00
            case 3: multiplier = 1.06
            default: multiplier = 1.20
            }
            let assessedBase = property.purchasePrice * 0.78
            let assessed = assessedBase * pow(1.03, Double(offset))
            return TaxYearPoint(year: year, taxAmount: baseTax * multiplier, assessedValue: assessed)
        }

        let state = property.state?.uppercased() ?? "TX"
        let ownerName = state == "TX" ? "Highland Crest Holdings LLC" : "Regional Property Trust"
        let city = property.city ?? "Dallas"
        let mailing = "PO Box 1182, \(city), \(state) \(property.zipCode ?? "00000")"
        let comparableRows: [ValuationScaleView.ComparableSnapshot] = [
            .init(
                title: "Comp A",
                address: "118 Amber Ln, \(city), \(state) \(property.zipCode ?? "00000")",
                estimate: property.purchasePrice * 0.90,
                bedrooms: 3,
                bathrooms: 2.0,
                squareFeet: 1520,
                daysOnMarket: 13
            ),
            .init(
                title: "Comp B",
                address: "240 Ridge Rd, \(city), \(state) \(property.zipCode ?? "00000")",
                estimate: property.purchasePrice * 0.96,
                bedrooms: 3,
                bathrooms: 2.5,
                squareFeet: 1660,
                daysOnMarket: 18
            ),
            .init(
                title: "Comp C",
                address: "75 Willow Dr, \(city), \(state) \(property.zipCode ?? "00000")",
                estimate: property.purchasePrice * 1.01,
                bedrooms: 4,
                bathrooms: 3.0,
                squareFeet: 1910,
                daysOnMarket: 10
            ),
            .init(
                title: "Comp D",
                address: "9 Pine Crest Ct, \(city), \(state) \(property.zipCode ?? "00000")",
                estimate: property.purchasePrice * 1.06,
                bedrooms: 4,
                bathrooms: 3.0,
                squareFeet: 2040,
                daysOnMarket: 8
            ),
            .init(
                title: "Comp E",
                address: "330 Oak Hollow St, \(city), \(state) \(property.zipCode ?? "00000")",
                estimate: property.purchasePrice * 1.13,
                bedrooms: 4,
                bathrooms: 3.5,
                squareFeet: 2190,
                daysOnMarket: 12
            )
        ]

        return IntelligenceScanData(
            ownerName: ownerName,
            mailingAddress: mailing,
            lastSaleDate: "2022-11-14",
            taxHistory: taxHistory,
            yearBuilt: 1998,
            floorCount: property.rentRoll.count >= 4 ? 2 : 1,
            zoningCode: state == "TX" ? "MF-2" : "R-4",
            squareFootage: max(Int(property.rentRoll.reduce(0) { $0 + ($1.squareFeet ?? 0) }), 1800),
            units: max(property.rentRoll.count, 1),
            lotSize: state == "TX" ? "7,200 sq ft" : "0.24 acres",
            hasHOA: state != "TX",
            subdivision: state == "TX" ? "Crestview Estates" : "North Ridge Commons",
            foundationType: state == "TX" ? "Slab" : "Basement",
            coolingType: state == "TX" ? "Central Electric" : "Heat Pump",
            heatingType: state == "TX" ? "Gas Furnace" : "Electric Baseboard",
            isOwnerOccupied: property.isOwned == true && property.rentRoll.count <= 2,
            hasGarage: true,
            hasPool: property.purchasePrice > 500000,
            valuationEstimate: property.purchasePrice * 1.03,
            valuationRangeMin: property.purchasePrice * 0.94,
            valuationRangeMax: property.purchasePrice * 1.10,
            comparables: comparableRows
        )
    }
}

private enum IntelligenceScanState {
    case notRequested
    case scanning
    case loaded
}

private struct IntelligenceScanData {
    let ownerName: String
    let mailingAddress: String
    let lastSaleDate: String
    let taxHistory: [TaxYearPoint]
    let yearBuilt: Int
    let floorCount: Int
    let zoningCode: String
    let squareFootage: Int
    let units: Int
    let lotSize: String
    let hasHOA: Bool
    let subdivision: String
    let foundationType: String
    let coolingType: String
    let heatingType: String
    let isOwnerOccupied: Bool
    let hasGarage: Bool
    let hasPool: Bool
    let valuationEstimate: Double
    let valuationRangeMin: Double
    let valuationRangeMax: Double
    let comparables: [ValuationScaleView.ComparableSnapshot]
}

private struct TaxYearPoint: Identifiable {
    var id: Int { year }
    let year: Int
    let taxAmount: Double
    let assessedValue: Double
}

private struct BlurredDataOverlay: View {
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Unlock with Pro")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.white)

            Button(action: onUnlock) {
                Text("Unlock with Pro")
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
                .fill(Color.black.opacity(0.74))
        )
    }
}

private struct ComparableDetailSheet: View {
    let comparable: ValuationScaleView.ComparableSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(comparable.title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)

            Text(comparable.address)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))

            HStack(spacing: 10) {
                detailChip("Estimate", shortCurrency(comparable.estimate))
                detailChip("Beds/Baths", "\(comparable.bedrooms) / \(String(format: "%.1f", comparable.bathrooms))")
                detailChip("DOM", "\(comparable.daysOnMarket)")
            }

            if let sqft = comparable.squareFeet {
                detailChip("SqFt", "\(sqft)")
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardSurface)
        )
        .padding(14)
        .presentationBackground(Color.canvasWhite)
    }

    private func detailChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryYellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
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

private struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [Color.clear, Color.primaryYellow.opacity(0.24), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .scaleEffect(2.0)
                .offset(x: phase * 240)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

#Preview("Deep Dive - Free") {
    NavigationStack {
        PropertyDeepDiveView(property: previewProperty)
            .environmentObject(previewSubscriptionManager(isPremium: false))
    }
}

#Preview("Deep Dive - Pro") {
    NavigationStack {
        PropertyDeepDiveView(property: previewProperty)
            .environmentObject(previewSubscriptionManager(isPremium: true))
    }
}

private var previewProperty: Property {
    Property(
        address: "123 Main St",
        city: "Dallas",
        state: "TX",
        zipCode: "75001",
        purchasePrice: 450000,
        rentRoll: [
            RentUnit(monthlyRent: 1900, unitType: "Unit 1", bedrooms: 2, bathrooms: 2, squareFeet: 980),
            RentUnit(monthlyRent: 1800, unitType: "Unit 2", bedrooms: 2, bathrooms: 1.5, squareFeet: 920)
        ],
        annualTaxes: 9800,
        annualInsurance: 1600,
        loanTermYears: 30,
        downPaymentPercent: 25,
        interestRate: 6.4,
        isOwned: true
    )
}

private func previewSubscriptionManager(isPremium: Bool) -> SubscriptionManager {
    let manager = SubscriptionManager()
    manager.setPreviewPremium(isPremium)
    return manager
}
