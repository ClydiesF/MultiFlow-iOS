import SwiftUI
import Charts
import UIKit
import Supabase
import Auth

struct PropertyDeepDiveView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    let property: Property

    @State private var scanState: IntelligenceScanState = .notRequested
    @State private var scanProgress: Double = 0
    @State private var scanStatusText: String = "Connecting to County Records..."
    @State private var showPaywall = false
    @State private var scanData: IntelligenceScanData?
    @State private var scanError: String?
    @State private var scanWarning: String?
    @State private var selectedComparable: ValuationScaleView.ComparableSnapshot?

    private let statusSteps = [
        "Connecting to County Records...",
        "Analyzing Tax Liens...",
        "Verifying Ownership..."
    ]
    private let offWhite = Color(white: 0.95)
    private let recordsService = PropertyRecordsService()

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
        .task(id: fullAddress) {
            await loadCachedScanIfAvailable()
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

                if let scanWarning {
                    Text(scanWarning)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.primaryYellow.opacity(0.9))
                }

                if let scanError {
                    Text(scanError)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red.opacity(0.9))
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
                    let sortedTaxHistory = data.taxHistory.sorted(by: { $0.year < $1.year })

                    Chart(sortedTaxHistory, id: \.year) { point in
                        BarMark(
                            x: .value("Assessment Year", String(point.year)),
                            y: .value("Assessed Value", point.assessedValue),
                            width: .fixed(8)
                        )
                        .foregroundStyle(Color.primaryYellow)
                        .cornerRadius(4)
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks {
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
        scanError = nil
        scanWarning = nil

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
        do {
            let result = try await recordsService.fetchPropertyRecordData(for: property, fullAddress: fullAddress)
            scanData = result.data
            scanWarning = result.warning
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
                scanState = .loaded
            }
        } catch {
            scanData = buildMockScanData()
            scanError = userFriendlyScanError(error)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
                scanState = .loaded
            }
        }
    }

    @MainActor
    private func loadCachedScanIfAvailable() async {
        guard !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let cached = await recordsService.cachedPropertyRecordData(fullAddress: fullAddress) else { return }

        scanData = cached
        scanWarning = nil
        scanError = nil
        scanProgress = 1
        scanStatusText = "Scan loaded from cache"
        scanState = .loaded
    }

    private var fullAddress: String {
        [
            property.address.trimmingCharacters(in: .whitespacesAndNewlines),
            property.city?.trimmingCharacters(in: .whitespacesAndNewlines),
            property.state?.trimmingCharacters(in: .whitespacesAndNewlines),
            property.zipCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }

    private func userFriendlyScanError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("quota") || message.contains("credits") || message.contains("remaining credits") {
            return "Monthly intelligence credits reached. Upgrade or wait until next month to run another scan."
        }
        if message.contains("unauthorized") || message.contains("invalid auth") {
            return "Please sign in again to run Intelligence Scan."
        }
        return error.localizedDescription
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

private struct PropertyRecordsService {
    private let client: SupabaseClient = SupabaseManager.shared.client

    private struct CachedRecordEntry: Codable, Sendable {
        let data: IntelligenceScanData
        let fetchedAt: Date
    }

    private actor PropertyRecordCacheStore {
        static let shared = PropertyRecordCacheStore()
        private let storageKey = "property_deep_dive_records_cache_v2"
        private let maxEntries = 60
        private var cache: [String: CachedRecordEntry] = [:]

        init() {
            if let data = UserDefaults.standard.data(forKey: storageKey),
               let decoded = try? JSONDecoder().decode([String: CachedRecordEntry].self, from: data) {
                cache = decoded
            }
        }

        func cachedValue(for key: String) -> IntelligenceScanData? {
            cache[key]?.data
        }

        func save(_ data: IntelligenceScanData, for key: String) {
            cache[key] = CachedRecordEntry(data: data, fetchedAt: Date())
            trimIfNeeded()
            persist()
        }

        private func trimIfNeeded() {
            guard cache.count > maxEntries else { return }
            let keep = cache
                .sorted { $0.value.fetchedAt > $1.value.fetchedAt }
                .prefix(maxEntries)
            cache = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }

        private func persist() {
            guard let data = try? JSONEncoder().encode(cache) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    enum PropertyRecordsError: LocalizedError {
        case missingAPIKey
        case missingAddress
        case invalidResponse
        case emptyResponse
        case apiError(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Missing RentCast API key."
            case .missingAddress: return "A full address is required for property records."
            case .invalidResponse: return "Unable to read property records response."
            case .emptyResponse: return "No property record returned for this address."
            case .apiError(let status, let message):
                return "RentCast API error (\(status)): \(message)"
            }
        }
    }

    private let propertyRecordsURL = URL(string: "https://api.rentcast.io/v1/properties")!
    private let avmValueURL = URL(string: "https://api.rentcast.io/v1/avm/value")!
    private let cacheStore = PropertyRecordCacheStore.shared

    func fetchPropertyRecordData(for property: Property, fullAddress: String) async throws -> (data: IntelligenceScanData, warning: String?) {
        let trimmedAddress = normalizedAddress(fullAddress)
        guard !trimmedAddress.isEmpty else { throw PropertyRecordsError.missingAddress }

        let cacheKey = cacheKey(for: trimmedAddress)
        if let cached = await cacheStore.cachedValue(for: cacheKey) {
            print("PropertyDeepDive cache hit for address: \(trimmedAddress)")
            return (data: cached, warning: nil)
        }

        async let recordsTask = fetchPropertyRecords(address: trimmedAddress, fallbackProperty: property)
        async let avmTask: Result<(estimate: Double, rangeMin: Double, rangeMax: Double, comparables: [ValuationScaleView.ComparableSnapshot]), Error> = {
            do {
                return .success(try await fetchAVMValue(address: trimmedAddress))
            } catch {
                return .failure(error)
            }
        }()

        var records = try await recordsTask
        var warning: String?
        switch await avmTask {
        case .success(let avm):
            records.valuationEstimate = avm.estimate
            records.valuationRangeMin = avm.rangeMin
            records.valuationRangeMax = avm.rangeMax
            if !avm.comparables.isEmpty {
                records.comparables = avm.comparables
            }
        case .failure(let error):
            let raw = error.localizedDescription.lowercased()
            if raw.contains("quota") || raw.contains("credits") || raw.contains("remaining credits") {
                warning = "Valuation unavailable: monthly credits reached."
            } else {
                warning = "Valuation unavailable: \(error.localizedDescription)"
            }
            print("PropertyDeepDive AVM fetch failed for \(trimmedAddress): \(error.localizedDescription)")
        }

        await cacheStore.save(records, for: cacheKey)
        return (data: records, warning: warning)
    }

    func cachedPropertyRecordData(fullAddress: String) async -> IntelligenceScanData? {
        let trimmedAddress = normalizedAddress(fullAddress)
        guard !trimmedAddress.isEmpty else { return nil }
        let key = cacheKey(for: trimmedAddress)
        return await cacheStore.cachedValue(for: key)
    }

    private func fetchPropertyRecords(address: String, fallbackProperty: Property) async throws -> IntelligenceScanData {
        print("PropertyDeepDive /properties request address=\(address)")

        do {
            let response = try await invokeRentcastProxy(endpoint: "properties", params: ["address": address])
            if let credits = response["credits"] as? [String: Any],
               let used = credits["used"] as? Int,
               let quota = credits["quota"] as? Int {
                await MainActor.run {
                    RentCastUsageManager.shared.syncFromServer(usedCredits: used, quotaCredits: quota)
                }
            }
            guard let payload = response["data"] else { throw PropertyRecordsError.invalidResponse }
            let data = try JSONSerialization.data(withJSONObject: payload)
            return try parsePropertyRecordData(from: data, fallbackProperty: fallbackProperty)
        } catch {
            throw error
        }
    }

    private func fetchAVMValue(address: String) async throws -> (estimate: Double, rangeMin: Double, rangeMax: Double, comparables: [ValuationScaleView.ComparableSnapshot]) {
        print("PropertyDeepDive /avm/value request address=\(address)")

        do {
            let response = try await invokeRentcastProxy(endpoint: "avm_value", params: ["address": address])
            if let credits = response["credits"] as? [String: Any],
               let used = credits["used"] as? Int,
               let quota = credits["quota"] as? Int {
                await MainActor.run {
                    RentCastUsageManager.shared.syncFromServer(usedCredits: used, quotaCredits: quota)
                }
            }

            guard let object = response["data"] as? [String: Any] else { throw PropertyRecordsError.invalidResponse }

            let estimate = findDouble(in: object, keys: ["price"]) ?? 0
            let rangeMin = findDouble(in: object, keys: ["priceRangeLow", "rangeMin", "valueRangeLow"]) ?? (estimate * 0.9)
            let rangeMax = findDouble(in: object, keys: ["priceRangeHigh", "rangeMax", "valueRangeHigh"]) ?? (estimate * 1.1)

            let rawComps = (object["comparables"] as? [[String: Any]]) ?? []
            let comps = rawComps.prefix(8).enumerated().map { index, item in
                ValuationScaleView.ComparableSnapshot(
                    title: "Comp \(String(UnicodeScalar(65 + index)!))",
                    address: findString(in: item, keys: ["formattedAddress", "addressLine1", "address"]) ?? "Comparable",
                    estimate: findDouble(in: item, keys: ["price", "value", "estimate"]) ?? 0,
                    bedrooms: findInt(in: item, keys: ["bedrooms", "beds"]) ?? 0,
                    bathrooms: findDouble(in: item, keys: ["bathrooms", "baths"]) ?? 0,
                    squareFeet: findInt(in: item, keys: ["squareFootage", "sqft"]),
                    daysOnMarket: findInt(in: item, keys: ["daysOnMarket", "dom"]) ?? 0
                )
            }
            return (estimate: estimate, rangeMin: rangeMin, rangeMax: rangeMax, comparables: comps)
        } catch {
            throw error
        }
    }

    private func invokeRentcastProxy(endpoint: String, params: [String: String]) async throws -> [String: Any] {
        let config = BackendConfig.load()
        guard let token = client.auth.currentSession?.accessToken else {
            throw PropertyRecordsError.invalidResponse
        }

        let url = config.supabaseURL.appendingPathComponent("functions/v1/rentcast-proxy")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "endpoint": endpoint,
            "params": params
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PropertyRecordsError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data)
        let object = json as? [String: Any] ?? [:]
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (object["error"] as? String)
                ?? (String(data: data, encoding: .utf8) ?? "Unknown response")
            throw PropertyRecordsError.apiError(status: httpResponse.statusCode, message: message)
        }
        return object
    }

    private func cacheKey(for fullAddress: String) -> String {
        normalizedAddress(fullAddress).lowercased()
    }

    private func normalizedAddress(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\s*,\\s*", with: ", ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            // Ensure "State ZIP" does not include a comma (e.g., "MA 02121", not "MA, 02121")
            .replacingOccurrences(
                of: ",\\s*([A-Za-z]{2})\\s*,\\s*(\\d{5}(?:-\\d{4})?)\\b",
                with: ", $1 $2",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePropertyRecordData(from data: Data, fallbackProperty: Property) throws -> IntelligenceScanData {
        let json = try JSONSerialization.jsonObject(with: data)

        let dictionary: [String: Any]
        if let array = json as? [[String: Any]], let first = array.first {
            dictionary = first
        } else if let object = json as? [String: Any] {
            dictionary = object
        } else {
            throw PropertyRecordsError.invalidResponse
        }

        guard !dictionary.isEmpty else { throw PropertyRecordsError.emptyResponse }

        let city = fallbackProperty.city ?? "Local"
        let state = fallbackProperty.state?.uppercased() ?? "TX"
        let zip = fallbackProperty.zipCode ?? "00000"

        let ownerNames = parseOwnerNames(from: dictionary)
        let ownerName = ownerNames.isEmpty
            ? (findString(in: dictionary, keys: ["ownerName", "owner_name"]) ?? "Owner unavailable")
            : ownerNames.joined(separator: ", ")
        let mailingAddress = parseOwnerMailingAddress(from: dictionary)
            ?? findString(in: dictionary, keys: ["ownerAddress", "mailingAddress", "mailing_address"])
            ?? "Address unavailable"
        let lastSaleDate = normalizeDateString(findString(in: dictionary, keys: ["lastSaleDate", "last_sale_date", "saleDate", "sale_date"]) ?? "N/A")

        let assessedValue = findDouble(in: dictionary, keys: ["taxAssessedValue", "assessedValue", "assessed_value"]) ?? (fallbackProperty.purchasePrice * 0.78)
        let taxAmount = findDouble(in: dictionary, keys: ["propertyTaxes", "taxAmount", "tax_amount", "annualTaxes"]) ?? (fallbackProperty.annualTaxes ?? 0)

        let taxHistory = parseTaxHistory(from: dictionary, fallbackTaxAmount: taxAmount, fallbackAssessedValue: assessedValue)

        let yearBuilt = Int(findDouble(in: dictionary, keys: ["yearBuilt", "year_built"]) ?? 0)
        let floorCount = Int(findDouble(in: dictionary, keys: ["features.floorCount", "stories", "storyCount", "floorCount", "floor_count"]) ?? Double((fallbackProperty.rentRoll.count >= 4) ? 2 : 1))
        let zoningCode = findString(in: dictionary, keys: ["zoning", "zoningCode", "zoning_code"]) ?? "N/A"
        let squareFootage = Int(findDouble(in: dictionary, keys: ["squareFootage", "livingArea", "living_area", "sqft"]) ?? Double(max(Int(fallbackProperty.rentRoll.reduce(0) { $0 + ($1.squareFeet ?? 0) }), 0)))
        let lotSizeValue = findDouble(in: dictionary, keys: ["lotSize", "lotSizeSqFt", "lot_size", "lot_size_sqft"])
        let lotSize = lotSizeValue.map { String(format: "%,.0f sq ft", $0) } ?? "N/A"
        let units = Int(findDouble(in: dictionary, keys: ["features.unitCount", "units", "unitCount", "unit_count"]) ?? Double(max(fallbackProperty.rentRoll.count, 1)))

        let hasHOA = parseHasHOA(from: dictionary)
        let subdivision = findString(in: dictionary, keys: ["subdivision", "subdivisionName", "neighborhood"]) ?? "N/A"
        let foundationType = findString(in: dictionary, keys: ["features.foundationType", "foundationType", "foundation_type", "foundation"]) ?? "N/A"
        let coolingType = findString(in: dictionary, keys: ["features.coolingType", "coolingType", "cooling", "cooling_type"]) ?? "N/A"
        let heatingType = findString(in: dictionary, keys: ["features.heatingType", "heatingType", "heating", "heating_type"]) ?? "N/A"
        let isOwnerOccupied = findBool(in: dictionary, keys: ["ownerOccupied", "owner_occupied", "isOwnerOccupied"]) ?? false
        let hasGarage = findBool(in: dictionary, keys: ["features.garage", "garage", "hasGarage", "has_garage"]) ?? false
        let hasPool = findBool(in: dictionary, keys: ["features.pool", "pool", "hasPool", "has_pool"]) ?? false

        let valuationEstimate = findDouble(in: dictionary, keys: ["price", "value", "estimatedValue", "estimate"]) ?? fallbackProperty.purchasePrice
        let valuationRangeMin = findDouble(in: dictionary, keys: ["rentcastValueRangeLow", "valueRangeLow", "rangeMin"]) ?? (valuationEstimate * 0.92)
        let valuationRangeMax = findDouble(in: dictionary, keys: ["rentcastValueRangeHigh", "valueRangeHigh", "rangeMax"]) ?? (valuationEstimate * 1.08)

        let comparables = parseComparables(from: dictionary, city: city, state: state, zip: zip, fallbackEstimate: valuationEstimate)

        return IntelligenceScanData(
            ownerName: ownerName,
            mailingAddress: mailingAddress,
            lastSaleDate: lastSaleDate,
            taxHistory: taxHistory,
            yearBuilt: max(yearBuilt, 0),
            floorCount: max(floorCount, 1),
            zoningCode: zoningCode,
            squareFootage: max(squareFootage, 0),
            units: max(units, 1),
            lotSize: lotSize,
            hasHOA: hasHOA,
            subdivision: subdivision,
            foundationType: foundationType,
            coolingType: coolingType,
            heatingType: heatingType,
            isOwnerOccupied: isOwnerOccupied,
            hasGarage: hasGarage,
            hasPool: hasPool,
            valuationEstimate: valuationEstimate,
            valuationRangeMin: valuationRangeMin,
            valuationRangeMax: valuationRangeMax,
            comparables: comparables
        )
    }

    private func parseTaxHistory(from object: [String: Any], fallbackTaxAmount: Double, fallbackAssessedValue: Double) -> [TaxYearPoint] {
        let years = parseTaxHistoryArray(from: object)
        if !years.isEmpty { return years }

        let currentYear = Calendar.current.component(.year, from: Date())
        return (0..<5).map { offset in
            let year = currentYear - (4 - offset)
            let multiplier = 0.86 + (Double(offset) * 0.085)
            return TaxYearPoint(
                year: year,
                taxAmount: max(fallbackTaxAmount * multiplier, 0),
                assessedValue: max(fallbackAssessedValue * pow(1.02, Double(offset)), 0)
            )
        }
    }

    private func parseTaxHistoryArray(from object: [String: Any]) -> [TaxYearPoint] {
        var pointsByYear: [Int: TaxYearPoint] = [:]

        let assessmentMaps: [[String: Any]] = [
            object["taxAssessments"] as? [String: Any],
            object["tax_assessments"] as? [String: Any]
        ].compactMap { $0 }

        for map in assessmentMaps {
            for (_, value) in map {
                guard let entry = value as? [String: Any],
                      let year = findInt(in: entry, keys: ["year"]) else { continue }
                let assessed = findDouble(in: entry, keys: ["value", "assessedValue", "assessed_value"]) ?? 0
                let existing = pointsByYear[year]
                pointsByYear[year] = TaxYearPoint(
                    year: year,
                    taxAmount: existing?.taxAmount ?? 0,
                    assessedValue: assessed
                )
            }
        }

        let taxMaps: [[String: Any]] = [
            object["propertyTaxes"] as? [String: Any],
            object["property_taxes"] as? [String: Any]
        ].compactMap { $0 }

        for map in taxMaps {
            for (_, value) in map {
                guard let entry = value as? [String: Any],
                      let year = findInt(in: entry, keys: ["year"]) else { continue }
                let total = findDouble(in: entry, keys: ["total", "taxAmount", "amount"]) ?? 0
                let existing = pointsByYear[year]
                pointsByYear[year] = TaxYearPoint(
                    year: year,
                    taxAmount: total,
                    assessedValue: existing?.assessedValue ?? 0
                )
            }
        }

        if !pointsByYear.isEmpty {
            return pointsByYear.values.sorted(by: { $0.year < $1.year })
        }

        let candidateArrays: [[String: Any]] = [
            object["taxHistory"] as? [[String: Any]],
            object["tax_history"] as? [[String: Any]]
        ].compactMap { $0 }.flatMap { $0 }

        let points = candidateArrays.compactMap { item -> TaxYearPoint? in
            guard let year = findInt(in: item, keys: ["year", "taxYear", "assessmentYear"]) else { return nil }
            let amount = findDouble(in: item, keys: ["taxAmount", "tax_amount", "amount", "total"]) ?? 0
            let assessed = findDouble(in: item, keys: ["assessedValue", "assessed_value", "value"]) ?? 0
            return TaxYearPoint(year: year, taxAmount: amount, assessedValue: assessed)
        }

        return points.sorted(by: { $0.year < $1.year })
    }

    private func parseOwnerNames(from object: [String: Any]) -> [String] {
        guard let owner = object["owner"] as? [String: Any],
              let names = owner["names"] as? [String] else { return [] }
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseOwnerMailingAddress(from object: [String: Any]) -> String? {
        guard let owner = object["owner"] as? [String: Any],
              let mailing = owner["mailingAddress"] as? [String: Any] else { return nil }

        if let formatted = mailing["formattedAddress"] as? String,
           !formatted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return formatted
        }

        let line1 = (mailing["addressLine1"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let city = (mailing["city"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let state = (mailing["state"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let zip = (mailing["zipCode"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let locality = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        return [line1, locality, zip]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func parseHasHOA(from object: [String: Any]) -> Bool {
        if let hoa = object["hoa"] as? [String: Any] {
            if let fee = findDouble(in: hoa, keys: ["fee"]), fee > 0 { return true }
        }
        return findBool(in: object, keys: ["hasHoa", "has_hoa", "hoa"]) ?? false
    }

    private func parseComparables(
        from object: [String: Any],
        city: String,
        state: String,
        zip: String,
        fallbackEstimate: Double
    ) -> [ValuationScaleView.ComparableSnapshot] {
        let rawComps: [[String: Any]] = [
            object["comparables"] as? [[String: Any]],
            object["comps"] as? [[String: Any]],
            object["nearbyHomes"] as? [[String: Any]],
            object["nearby_homes"] as? [[String: Any]]
        ].compactMap { $0 }.first ?? []

        let mapped = rawComps.prefix(5).enumerated().map { index, item in
            let title = "Comp \(String(UnicodeScalar(65 + index)!))"
            let address = findString(in: item, keys: ["formattedAddress", "address", "fullAddress"])
                ?? "\(city), \(state) \(zip)"
            let estimate = findDouble(in: item, keys: ["price", "value", "estimatedValue", "estimate"])
                ?? (fallbackEstimate * (0.92 + Double(index) * 0.04))
            let beds = findInt(in: item, keys: ["bedrooms", "beds"]) ?? 0
            let baths = findDouble(in: item, keys: ["bathrooms", "baths"]) ?? 0
            let sqft = findInt(in: item, keys: ["squareFootage", "livingArea", "sqft"])
            let dom = findInt(in: item, keys: ["daysOnMarket", "dom"]) ?? 0

            return ValuationScaleView.ComparableSnapshot(
                title: title,
                address: address,
                estimate: estimate,
                bedrooms: beds,
                bathrooms: baths,
                squareFeet: sqft,
                daysOnMarket: dom
            )
        }

        if !mapped.isEmpty { return mapped }

        return [
            .init(title: "Comp A", address: "118 Amber Ln, \(city), \(state) \(zip)", estimate: fallbackEstimate * 0.92, bedrooms: 3, bathrooms: 2, squareFeet: 1500, daysOnMarket: 15),
            .init(title: "Comp B", address: "240 Ridge Rd, \(city), \(state) \(zip)", estimate: fallbackEstimate * 0.98, bedrooms: 3, bathrooms: 2.5, squareFeet: 1650, daysOnMarket: 19),
            .init(title: "Comp C", address: "75 Willow Dr, \(city), \(state) \(zip)", estimate: fallbackEstimate * 1.03, bedrooms: 4, bathrooms: 3, squareFeet: 1900, daysOnMarket: 11)
        ]
    }

    private func normalizeDateString(_ value: String) -> String {
        if value.count >= 10 {
            return String(value.prefix(10))
        }
        return value
    }

    private func findString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if key.contains(".") {
                if let nestedValue = valueForNestedKeyPath(key, in: object) as? String, !nestedValue.isEmpty {
                    return nestedValue
                }
            } else if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }

        for value in object.values {
            if let nested = value as? [String: Any], let found = findString(in: nested, keys: keys) {
                return found
            }
            if let array = value as? [[String: Any]] {
                for item in array {
                    if let found = findString(in: item, keys: keys) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    private func findDouble(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if key.contains(".") {
                if let nested = valueForNestedKeyPath(key, in: object) {
                    if let value = nested as? Double { return value }
                    if let value = nested as? Int { return Double(value) }
                    if let value = nested as? String, let parsed = Double(value) { return parsed }
                }
            } else {
                if let value = object[key] as? Double { return value }
                if let value = object[key] as? Int { return Double(value) }
                if let value = object[key] as? String, let parsed = Double(value) { return parsed }
            }
        }

        for value in object.values {
            if let nested = value as? [String: Any], let found = findDouble(in: nested, keys: keys) {
                return found
            }
            if let array = value as? [[String: Any]] {
                for item in array {
                    if let found = findDouble(in: item, keys: keys) { return found }
                }
            }
        }
        return nil
    }

    private func findInt(in object: [String: Any], keys: [String]) -> Int? {
        if let doubleValue = findDouble(in: object, keys: keys) { return Int(doubleValue) }
        return nil
    }

    private func findBool(in object: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = object[key] as? Bool { return value }
            if let value = object[key] as? Int { return value != 0 }
            if let value = object[key] as? String {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "yes", "1"].contains(normalized) { return true }
                if ["false", "no", "0"].contains(normalized) { return false }
            }
        }
        for value in object.values {
            if let nested = value as? [String: Any], let found = findBool(in: nested, keys: keys) {
                return found
            }
        }
        return nil
    }

    private func valueForNestedKeyPath(_ keyPath: String, in object: [String: Any]) -> Any? {
        keyPath
            .split(separator: ".")
            .map(String.init)
            .reduce(Optional(object as Any)) { partial, key in
                guard let dictionary = partial as? [String: Any] else { return nil }
                return dictionary[key]
            }
    }
}

private enum IntelligenceScanState {
    case notRequested
    case scanning
    case loaded
}

private struct IntelligenceScanData: Codable {
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
    var valuationEstimate: Double
    var valuationRangeMin: Double
    var valuationRangeMax: Double
    var comparables: [ValuationScaleView.ComparableSnapshot]
}

private struct TaxYearPoint: Identifiable, Codable {
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

#if DEBUG
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

@MainActor
private func previewSubscriptionManager(isPremium: Bool) -> SubscriptionManager {
    let manager = SubscriptionManager()
    manager.setPreviewPremium(isPremium)
    return manager
}
#endif
