import Foundation
import Supabase
import Auth

struct MarketInsightsService {
    struct RentalMarketAVMSnapshot: Codable, Sendable {
        struct Comparable: Codable, Sendable {
            let address: String
            let monthlyRent: Double
            let distanceMiles: Double
        }

        let rent: Double
        let rentRangeLow: Double
        let rentRangeHigh: Double
        let comparables: [Comparable]
    }

    private struct CachedInsightEntry: Codable, Sendable {
        let snapshot: MarketInsightSnapshot
        let fetchedAt: Date
    }

    private struct CachedRentAVMEntry: Codable, Sendable {
        let snapshot: RentalMarketAVMSnapshot
        let fetchedAt: Date
    }

    private actor MarketInsightsCacheStore {
        static let shared = MarketInsightsCacheStore()
        private let storageKey = "market_insights_cache_v1"
        private let rentAVMStorageKey = "market_rent_avm_cache_v1"
        private var cache: [String: CachedInsightEntry] = [:]
        private var rentAVMCache: [String: CachedRentAVMEntry] = [:]

        init() {
            if let data = UserDefaults.standard.data(forKey: storageKey),
               let decoded = try? JSONDecoder().decode([String: CachedInsightEntry].self, from: data) {
                cache = decoded
            }
            if let data = UserDefaults.standard.data(forKey: rentAVMStorageKey),
               let decoded = try? JSONDecoder().decode([String: CachedRentAVMEntry].self, from: data) {
                rentAVMCache = decoded
            }
        }

        func freshValue(for key: String, maxAge: TimeInterval) -> MarketInsightSnapshot? {
            guard let entry = cache[key] else { return nil }
            let age = Date().timeIntervalSince(entry.fetchedAt)
            return age <= maxAge ? entry.snapshot : nil
        }

        func cachedValue(for key: String) -> MarketInsightSnapshot? {
            cache[key]?.snapshot
        }

        func save(_ snapshot: MarketInsightSnapshot, for key: String) {
            cache[key] = CachedInsightEntry(snapshot: snapshot, fetchedAt: Date())
            persist()
        }

        func rentAVMValue(for key: String) -> RentalMarketAVMSnapshot? {
            rentAVMCache[key]?.snapshot
        }

        func saveRentAVM(_ snapshot: RentalMarketAVMSnapshot, for key: String) {
            rentAVMCache[key] = CachedRentAVMEntry(snapshot: snapshot, fetchedAt: Date())
            persist()
        }

        private func persist() {
            guard let data = try? JSONEncoder().encode(cache) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
            guard let rentData = try? JSONEncoder().encode(rentAVMCache) else { return }
            UserDefaults.standard.set(rentData, forKey: rentAVMStorageKey)
        }
    }

    enum InsightError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case emptyData

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing RentCast API key."
            case .invalidResponse:
                return "Unable to read market trend response."
            case .emptyData:
                return "No market trend data returned for this area."
            }
        }
    }

    private let baseURL = URL(string: "https://api.rentcast.io/v1")!
    private let cacheTTL: TimeInterval = 60 * 60 * 24
    private let cacheStore = MarketInsightsCacheStore.shared

    func fetchMarketInsights(zipCode: String, city: String?, state: String?) async throws -> MarketInsightSnapshot {
        let cacheKey = buildCacheKey(zipCode: zipCode, city: city, state: state)
        if let cached = await cacheStore.freshValue(for: cacheKey, maxAge: cacheTTL) {
            return cached
        }

        do {
            let response = try await invokeRentcastProxy(endpoint: "markets", params: [
                "zipCode": zipCode
            ])
            let payload = response["data"] ?? response
            let serialized = try JSONSerialization.data(withJSONObject: payload)
            let snapshot = try parseMarketSnapshot(from: serialized)
            if let credits = response["credits"] as? [String: Any],
               let used = credits["used"] as? Int,
               let quota = credits["quota"] as? Int {
                await MainActor.run {
                    RentCastUsageManager.shared.syncFromServer(usedCredits: used, quotaCredits: quota)
                }
            }
            await cacheStore.save(snapshot, for: cacheKey)
            return snapshot
        } catch {
            // Fall back to last cached value (even if stale) to avoid blocking UI
            // when the network or quota is temporarily unavailable.
            if let cached = await cacheStore.cachedValue(for: cacheKey) {
                return cached
            }
            throw error
        }
    }

    func suggestMonthlyRentPerUnit(city: String?, state: String?) async -> Double {
        // Placeholder service surface for premium API-backed market insights.
        // This is intentionally deterministic until live API wiring is added.
        let stateKey = (state ?? "").uppercased()
        let cityKey = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if stateKey == "CA" { return 2600 }
        if stateKey == "NY" { return 2800 }
        if stateKey == "TX" {
            if cityKey == "dallas" { return 1800 }
            if cityKey == "austin" { return 2100 }
            return 1750
        }
        if stateKey == "FL" { return 1950 }
        return 1650
    }

    func fetchLongTermRentAVM(fullAddress: String) async throws -> RentalMarketAVMSnapshot {
        let normalizedAddress = fullAddress
            .replacingOccurrences(of: "\\s*,\\s*", with: ", ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAddress.isEmpty else {
            throw InsightError.invalidResponse
        }

        let cacheKey = "rent_avm::\(normalizedAddress.lowercased())"
        if let cached = await cacheStore.rentAVMValue(for: cacheKey) {
            return cached
        }

        do {
            let response = try await invokeRentcastProxy(endpoint: "avm_rent", params: [
                "address": normalizedAddress
            ])
            let object = (response["data"] as? [String: Any]) ?? response
            if object.isEmpty {
                throw InsightError.invalidResponse
            }

            let rent = findDouble(in: object, keys: ["rent", "price", "estimate", "value"]) ?? 0
            let rangeLow = findDouble(in: object, keys: ["rentRangeLow", "priceRangeLow", "rangeLow"]) ?? (rent * 0.9)
            let rangeHigh = findDouble(in: object, keys: ["rentRangeHigh", "priceRangeHigh", "rangeHigh"]) ?? (rent * 1.1)

            let rawComps = (object["comparables"] as? [[String: Any]]) ?? []
            let comps: [RentalMarketAVMSnapshot.Comparable] = rawComps.prefix(8).compactMap { comp in
                let address = findString(in: comp, keys: ["formattedAddress", "addressLine1", "address"]) ?? "Comparable"
                let monthlyRent = findDouble(in: comp, keys: ["rent", "price", "estimate", "value"]) ?? 0
                let distance = findDouble(in: comp, keys: ["distance", "distanceMiles"]) ?? 0
                guard monthlyRent > 0 else { return nil }
                return .init(address: address, monthlyRent: monthlyRent, distanceMiles: distance)
            }

            let snapshot = RentalMarketAVMSnapshot(
                rent: max(rent, 0),
                rentRangeLow: max(rangeLow, 0),
                rentRangeHigh: max(rangeHigh, 0),
                comparables: comps
            )
            if let credits = response["credits"] as? [String: Any],
               let used = credits["used"] as? Int,
               let quota = credits["quota"] as? Int {
                await MainActor.run {
                    RentCastUsageManager.shared.syncFromServer(usedCredits: used, quotaCredits: quota)
                }
            }
            await MainActor.run {
                RentCastUsageManager.shared.ensureCurrentMonth()
            }
            await cacheStore.saveRentAVM(snapshot, for: cacheKey)
            return snapshot
        } catch {
            throw error
        }
    }

    private func invokeRentcastProxy(endpoint: String, params: [String: String]) async throws -> [String: Any] {
        let config = BackendConfig.load()
        guard let token = SupabaseManager.shared.client.auth.currentSession?.accessToken else {
            throw InsightError.invalidResponse
        }

        let url = config.supabaseURL.appendingPathComponent("functions/v1/rentcast-proxy")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "endpoint": endpoint,
            "params": params
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InsightError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data)
        let object = json as? [String: Any] ?? [:]

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let message = object["error"] as? String, !message.isEmpty {
                throw NSError(domain: "RentcastProxy", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: message
                ])
            }
            throw InsightError.invalidResponse
        }

        return object
    }

    func estimatedTaxRate(state: String?) async -> Double? {
        let table: [String: Double] = [
            "AL": 0.0040, "AK": 0.0119, "AZ": 0.0060, "AR": 0.0061,
            "CA": 0.0071, "CO": 0.0049, "CT": 0.0214, "DE": 0.0057,
            "FL": 0.0089, "GA": 0.0092, "HI": 0.0031, "ID": 0.0063,
            "IL": 0.0227, "IN": 0.0085, "IA": 0.0151, "KS": 0.0141,
            "KY": 0.0086, "LA": 0.0056, "ME": 0.0124, "MD": 0.0113,
            "MA": 0.0115, "MI": 0.0147, "MN": 0.0109, "MS": 0.0081,
            "MO": 0.0097, "MT": 0.0074, "NE": 0.0161, "NV": 0.0055,
            "NH": 0.0186, "NJ": 0.0242, "NM": 0.0080, "NY": 0.0160,
            "NC": 0.0084, "ND": 0.0099, "OH": 0.0141, "OK": 0.0085,
            "OR": 0.0090, "PA": 0.0135, "RI": 0.0137, "SC": 0.0056,
            "SD": 0.0122, "TN": 0.0068, "TX": 0.0223, "UT": 0.0060,
            "VT": 0.0190, "VA": 0.0080, "WA": 0.0088, "WV": 0.0059,
            "WI": 0.0131, "WY": 0.0051
        ]
        return table[(state ?? "").uppercased()]
    }

    private func parseMarketSnapshot(from data: Data) throws -> MarketInsightSnapshot {
        let jsonObject = try JSONSerialization.jsonObject(with: data)

        if let object = jsonObject as? [String: Any] {
            if let snapshot = snapshotFrom(dictionary: object) {
                return snapshot
            }
        }

        if let array = jsonObject as? [[String: Any]], !array.isEmpty {
            for object in array {
                if let snapshot = snapshotFrom(dictionary: object) {
                    return snapshot
                }
            }
        }

        throw InsightError.emptyData
    }

    private func snapshotFrom(dictionary: [String: Any]) -> MarketInsightSnapshot? {
        let rentalData = (dictionary["rentalData"] as? [String: Any]) ?? dictionary

        let medianRent = findDouble(in: rentalData, keys: ["medianRent", "rentMedian"]) ?? 0
        let averageRent = findDouble(in: rentalData, keys: ["averageRent", "avgRent", "rentAverage"]) ?? medianRent
        let currentDom = findInt(
            in: rentalData,
            keys: [
                "medianDaysOnMarket",
                "averageDaysOnMarket",
                "avgDaysOnMarket",
                "daysOnMarket",
                "dom"
            ]
        )
        let currentInventory = findDouble(
            in: rentalData,
            keys: ["totalListings", "activeListings", "inventory", "inventoryCount", "newListings"]
        )
        let totalListings = findInt(in: rentalData, keys: ["totalListings", "activeListings", "inventory", "inventoryCount"]) ?? 0
        let newListings = findInt(in: rentalData, keys: ["newListings"]) ?? 0
        let explicitInventoryLevel = findString(
            in: rentalData,
            keys: ["inventoryLevel", "inventoryStatus", "inventory_level", "inventory_status"]
        )

        let history = extractHistoryPoints(from: rentalData)
        let latestPoint = latestHistoryPoint(from: history)
        let baselinePoint = baselineHistoryPoint(for: latestPoint, history: history)

        let rentGrowthYoY: Double = {
            if let directGrowth = findDouble(
                in: rentalData,
                keys: ["rentGrowthYoY", "rent_growth_yoy", "yearOverYearRentGrowth", "yoyRentGrowth"]
            ) {
                return directGrowth
            }
            guard let latestRent = latestPoint?.rent ?? (medianRent > 0 ? medianRent : nil),
                  let baselineRent = baselinePoint?.rent,
                  baselineRent > 0 else {
                return 0
            }
            return ((latestRent - baselineRent) / baselineRent) * 100
        }()

        let daysOnMarket = latestPoint?.daysOnMarket ?? currentDom ?? 0

        let inventoryLevel: String = {
            if let explicitInventoryLevel {
                return normalizeInventoryLevel(from: explicitInventoryLevel)
            }
            let inventoryValue = latestPoint?.inventory ?? currentInventory ?? Double(totalListings)
            if inventoryValue > 0 {
                let newListingsValue = max(1, newListings)
                let turnoverRatio = Double(newListingsValue) / inventoryValue
                if turnoverRatio >= 0.33 { return "Tight" }
                if turnoverRatio <= 0.12 { return "Leased" }
                return "Balanced"
            }
            return "Tight"
        }()

        let hasUsableSignal = (medianRent > 0 || averageRent > 0) || (currentDom != nil) || !history.isEmpty || (currentInventory != nil)
        guard hasUsableSignal else { return nil }

        return MarketInsightSnapshot(
            medianRent: medianRent > 0 ? medianRent : averageRent,
            averageRent: averageRent > 0 ? averageRent : medianRent,
            rentGrowthYoYPercent: rentGrowthYoY,
            daysOnMarket: daysOnMarket,
            newListings: newListings,
            totalListings: totalListings,
            inventoryLevel: inventoryLevel
        )
    }

    private struct HistoryPoint {
        let date: Date?
        let rent: Double?
        let daysOnMarket: Int?
        let inventory: Double?
    }

    private func extractHistoryPoints(from object: [String: Any]) -> [HistoryPoint] {
        if let historyArray = object["history"] as? [[String: Any]] {
            return historyArray.map { item in
                let rent = findDouble(in: item, keys: ["medianRent", "averageRent", "avgRent", "rent"])
                let dom = findInt(
                    in: item,
                    keys: ["medianDaysOnMarket", "averageDaysOnMarket", "avgDaysOnMarket", "daysOnMarket", "dom"]
                )
                let inventory = findDouble(in: item, keys: ["totalListings", "activeListings", "inventory", "newListings"])
                let date = parseHistoryDate(from: item, fallbackKey: nil)
                return HistoryPoint(date: date, rent: rent, daysOnMarket: dom, inventory: inventory)
            }
        }

        if let historyDictionary = object["history"] as? [String: Any] {
            return historyDictionary.compactMap { key, rawValue in
                guard let item = rawValue as? [String: Any] else { return nil }
                let rent = findDouble(in: item, keys: ["medianRent", "averageRent", "avgRent", "rent"])
                let dom = findInt(
                    in: item,
                    keys: ["medianDaysOnMarket", "averageDaysOnMarket", "avgDaysOnMarket", "daysOnMarket", "dom"]
                )
                let inventory = findDouble(in: item, keys: ["totalListings", "activeListings", "inventory", "newListings"])
                let date = parseHistoryDate(from: item, fallbackKey: key)
                return HistoryPoint(date: date, rent: rent, daysOnMarket: dom, inventory: inventory)
            }
        }

        return []
    }

    private func parseHistoryDate(from object: [String: Any], fallbackKey: String?) -> Date? {
        let raw = findString(in: object, keys: ["date", "month", "period", "timestamp"]) ?? fallbackKey
        guard let raw else { return nil }

        let isoDate = ISO8601DateFormatter()
        if let full = isoDate.date(from: raw) { return full }

        let yearMonth = DateFormatter()
        yearMonth.dateFormat = "yyyy-MM"
        yearMonth.locale = Locale(identifier: "en_US_POSIX")
        if let monthDate = yearMonth.date(from: raw) { return monthDate }

        let fullDate = DateFormatter()
        fullDate.dateFormat = "yyyy-MM-dd"
        fullDate.locale = Locale(identifier: "en_US_POSIX")
        return fullDate.date(from: raw)
    }

    private func latestHistoryPoint(from history: [HistoryPoint]) -> HistoryPoint? {
        guard !history.isEmpty else { return nil }
        let withDates = history.compactMap { point -> (HistoryPoint, Date)? in
            guard let date = point.date else { return nil }
            return (point, date)
        }
        if let datedLatest = withDates.max(by: { $0.1 < $1.1 })?.0 {
            return datedLatest
        }
        return history.last
    }

    private func baselineHistoryPoint(for latest: HistoryPoint?, history: [HistoryPoint]) -> HistoryPoint? {
        guard let latestDate = latest?.date else { return history.min(by: { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }) }
        let calendar = Calendar(identifier: .gregorian)
        let candidates = history.compactMap { point -> (HistoryPoint, Int)? in
            guard let date = point.date else { return nil }
            let monthDiff = abs((calendar.dateComponents([.month], from: date, to: latestDate).month ?? 0))
            return (point, monthDiff)
        }
        if let aroundOneYear = candidates.min(by: { abs($0.1 - 12) < abs($1.1 - 12) })?.0 {
            return aroundOneYear
        }
        return history.min(by: { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) })
    }

    private func findDouble(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = object[key] as? Double {
                return value
            }
            if let value = object[key] as? Int {
                return Double(value)
            }
            if let value = object[key] as? String,
               let parsed = Double(value) {
                return parsed
            }
        }

        for value in object.values {
            if let nested = value as? [String: Any],
               let found = findDouble(in: nested, keys: keys) {
                return found
            }
            if let nestedArray = value as? [[String: Any]] {
                for item in nestedArray {
                    if let found = findDouble(in: item, keys: keys) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    private func findInt(in object: [String: Any], keys: [String]) -> Int? {
        if let value = findDouble(in: object, keys: keys) {
            return Int(round(value))
        }
        return nil
    }

    private func findString(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }

        for value in object.values {
            if let nested = value as? [String: Any],
               let found = findString(in: nested, keys: keys) {
                return found
            }
            if let nestedArray = value as? [[String: Any]] {
                for item in nestedArray {
                    if let found = findString(in: item, keys: keys) {
                        return found
                    }
                }
            }
        }
        return nil
    }

    private func normalizeInventoryLevel(from raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("tight") || normalized.contains("low") {
            return "Tight"
        }
        if normalized.contains("lease") || normalized.contains("high") {
            return "Leased"
        }
        return raw
    }

    private func buildCacheKey(zipCode: String, city: String?, state: String?) -> String {
        let normalizedZip = zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedZip
    }
}
