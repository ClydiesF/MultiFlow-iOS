import Foundation
import Combine
import RevenueCat

struct RentCastUsageSnapshot: Codable, Equatable, Sendable {
    let monthKey: String
    var usedCredits: Int
    var quotaCredits: Int
    var endpointCounts: [String: Int]

    var remainingCredits: Int {
        max(quotaCredits - usedCredits, 0)
    }

    var usageRatio: Double {
        guard quotaCredits > 0 else { return 1 }
        return min(Double(usedCredits) / Double(quotaCredits), 1)
    }
}

@MainActor
final class RentCastUsageManager: ObservableObject {
    enum Endpoint: String, CaseIterable, Sendable {
        case markets
        case rentAVM
        case valueAVM
        case properties

        var creditCost: Int {
            switch self {
            case .markets, .rentAVM, .valueAVM:
                return 1
            case .properties:
                return 2
            }
        }
    }

    enum UsageError: LocalizedError {
        case quotaExceeded(remaining: Int)

        var errorDescription: String? {
            switch self {
            case .quotaExceeded(let remaining):
                return remaining <= 0
                    ? "Monthly market data quota reached. Upgrade plan or wait for next month."
                    : "Not enough monthly credits for this action."
            }
        }
    }

    static let shared = RentCastUsageManager()

    @Published private(set) var snapshot: RentCastUsageSnapshot

    private let storageKey = "rentcast_usage_v1"
    private let defaultQuotaCredits = 25
    private var reservations: [UUID: (cost: Int, endpoint: Endpoint)] = [:]

    private init() {
        let month = Self.currentMonthKey()
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(RentCastUsageSnapshot.self, from: data),
           decoded.monthKey == month {
            snapshot = decoded
        } else {
            snapshot = RentCastUsageSnapshot(
                monthKey: month,
                usedCredits: 0,
                quotaCredits: defaultQuotaCredits,
                endpointCounts: [:]
            )
            persist()
        }
    }

    func ensureCurrentMonth() {
        let month = Self.currentMonthKey()
        guard snapshot.monthKey != month else { return }
        snapshot = RentCastUsageSnapshot(
            monthKey: month,
            usedCredits: 0,
            quotaCredits: defaultQuotaCredits,
            endpointCounts: [:]
        )
        reservations.removeAll()
        persist()
    }

    func reserve(_ endpoint: Endpoint) throws -> UUID {
        ensureCurrentMonth()
        let pendingCost = reservations.values.reduce(0) { $0 + $1.cost }
        let available = max(snapshot.quotaCredits - snapshot.usedCredits - pendingCost, 0)
        guard available >= endpoint.creditCost else {
            throw UsageError.quotaExceeded(remaining: max(snapshot.remainingCredits - pendingCost, 0))
        }
        let token = UUID()
        reservations[token] = (endpoint.creditCost, endpoint)
        return token
    }

    func commit(_ token: UUID) {
        ensureCurrentMonth()
        guard let reservation = reservations.removeValue(forKey: token) else { return }
        snapshot.usedCredits += reservation.cost
        snapshot.endpointCounts[reservation.endpoint.rawValue, default: 0] += 1
        persist()
    }

    func syncFromServer(usedCredits: Int, quotaCredits: Int) {
        ensureCurrentMonth()
        snapshot.usedCredits = max(usedCredits, 0)
        snapshot.quotaCredits = max(quotaCredits, 0)
        persist()
    }

    func cancel(_ token: UUID) {
        _ = reservations.removeValue(forKey: token)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func currentMonthKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}

@MainActor
final class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    enum BillingPlan: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case annual = "Annual"

        var id: String { rawValue }
    }

    private enum Constants {
        static let fallbackEntitlementID = "MultiFlow: Property Evaluator Pro"
        static let monthlyPackageID = "monthly"
        static let yearlyPackageID = "yearly"
        static let annualPackageID = "annual"
        static let lifetimePackageID = "lifetime"
    }

    @Published private(set) var isPremium: Bool
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var currentOffering: Offering?
    @Published private(set) var availablePackages: [Package] = []
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var configured = false
    @Published var selectedPlan: BillingPlan = .annual
    @Published var lastErrorMessage: String?

    private var customerInfoStreamTask: Task<Void, Never>?

    override init() {
        isPremium = UserDefaults.standard.bool(forKey: "isPremiumUser")
        super.init()
    }

    func checkAccess(feature: FeatureType) -> Bool {
        switch feature {
        case .autoFillAddress, .marketRentSuggestion, .nationwideTaxes, .marketInsights, .dealRooms, .offerTracker:
            return isPremium
        }
    }

    func configureIfNeeded() {
        guard !configured else { return }

        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
#if DEBUG
        let resolvedKey = "test_tLWwpGYldPETCFplXsTRbTxdlOI"
#else
        let resolvedKey = apiKey ?? ""
#endif

        guard !resolvedKey.isEmpty else {
            lastErrorMessage = "Missing RevenueCat API key for this build."
            return
        }

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: resolvedKey)
        Purchases.shared.delegate = self
        configured = true

        customerInfoStreamTask?.cancel()
        customerInfoStreamTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self.applyCustomerInfo(info)
                }
            }
        }

        Task {
            await refreshCustomerInfo()
            await refreshOfferings()
        }
    }

    func syncAuthUser(_ appUserID: String?) async {
        configureIfNeeded()
        guard configured else { return }

        let sanitized = appUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let userID = sanitized, !userID.isEmpty {
                let result = try await Purchases.shared.logIn(userID)
                applyCustomerInfo(result.customerInfo)
            } else {
                let info = try await Purchases.shared.logOut()
                applyCustomerInfo(info)
            }
        } catch {
            lastErrorMessage = "RevenueCat auth sync failed: \(error.localizedDescription)"
        }
    }

    func refreshOfferings() async {
        configureIfNeeded()
        guard configured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        lastErrorMessage = nil

        do {
            let offerings = try await Purchases.shared.offerings()
            let resolvedOffering = resolveOffering(from: offerings)
            currentOffering = resolvedOffering

            if let resolvedOffering {
                availablePackages = resolvedOffering.availablePackages
            } else {
                availablePackages = offerings.all.values.flatMap(\.availablePackages)
            }

            if availablePackages.isEmpty {
                let availableOfferingIDs = offerings.all.keys.sorted().joined(separator: ", ")
                lastErrorMessage = availableOfferingIDs.isEmpty
                    ? "No subscription products are configured in RevenueCat for this app."
                    : "No packages found in offerings (\(availableOfferingIDs)). Set a current offering and add monthly/annual packages."
            }
        } catch {
            lastErrorMessage = "Unable to load subscription options. \(error.localizedDescription)"
        }
    }

    func refreshCustomerInfo() async {
        configureIfNeeded()
        guard configured else { return }

        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            lastErrorMessage = "Unable to load subscription status."
        }
    }

    func purchaseSelectedPlan() async -> Bool {
        guard let package = selectedPackage else {
            lastErrorMessage = "No package found for the selected plan."
            return false
        }
        return await purchase(package: package)
    }

    func purchaseLifetime() async -> Bool {
        guard let package = lifetimePackage else {
            lastErrorMessage = "Lifetime package is not available."
            return false
        }
        return await purchase(package: package)
    }

    func restorePurchases() async -> Bool {
        configureIfNeeded()
        guard configured else { return false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            return true
        } catch {
            lastErrorMessage = "Restore failed. Please try again."
            return false
        }
    }

    var selectedPlanPriceLabel: String {
        selectedPackage?.storeProduct.localizedPriceString ?? "Unavailable"
    }

    var selectedPlanSubtitle: String {
        selectedPackage?.storeProduct.localizedTitle ?? "Pro Plan"
    }

    var lifetimePriceLabel: String {
        lifetimePackage?.storeProduct.localizedPriceString ?? "Unavailable"
    }

    var entitlementID: String {
        let configuredID = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PRO_ENTITLEMENT_ID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (configuredID?.isEmpty == false) ? configuredID! : Constants.fallbackEntitlementID
    }

    var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly:
            return package(matchingAnyIdentifier: [Constants.monthlyPackageID, "$rc_monthly"])
        case .annual:
            return package(matchingAnyIdentifier: [Constants.yearlyPackageID, Constants.annualPackageID, "$rc_annual"])
        }
    }

    var lifetimePackage: Package? {
        package(matchingAnyIdentifier: [Constants.lifetimePackageID, "$rc_lifetime"])
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        applyCustomerInfo(customerInfo)
    }

    private func purchase(package: Package) async -> Bool {
        configureIfNeeded()
        guard configured else { return false }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            applyCustomerInfo(result.customerInfo)
            return isPremium
        } catch {
            if error.localizedDescription.lowercased().contains("cancel") {
                return false
            }
            lastErrorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    private func package(matchingAnyIdentifier identifiers: [String]) -> Package? {
        let normalized = Set(identifiers.map { $0.lowercased() })
        if let match = availablePackages.first(where: { pkg in
            normalized.contains(pkg.identifier.lowercased()) ||
            normalized.contains(pkg.storeProduct.productIdentifier.lowercased())
        }) {
            return match
        }

        // Fallback for projects that use custom package IDs.
        switch selectedPlan {
        case .monthly:
            return availablePackages.first { pkg in
                let id = pkg.identifier.lowercased()
                let productID = pkg.storeProduct.productIdentifier.lowercased()
                return id.contains("month") || productID.contains("month")
            }
        case .annual:
            return availablePackages.first { pkg in
                let id = pkg.identifier.lowercased()
                let productID = pkg.storeProduct.productIdentifier.lowercased()
                return id.contains("year") || id.contains("annual")
                || productID.contains("year") || productID.contains("annual")
            }
        }
    }

    private func resolveOffering(from offerings: Offerings) -> Offering? {
        if let current = offerings.current, !current.availablePackages.isEmpty {
            return current
        }

        return offerings.all.values.first(where: { !$0.availablePackages.isEmpty })
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        isPremium = info.entitlements[entitlementID]?.isActive == true
        UserDefaults.standard.set(isPremium, forKey: "isPremiumUser")
    }
}

#if DEBUG
extension SubscriptionManager {
    func setPreviewPremium(_ value: Bool) {
        isPremium = value
    }
}
#endif
