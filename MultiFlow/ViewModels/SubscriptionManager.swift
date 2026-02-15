import Foundation
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: NSObject, ObservableObject, PurchasesDelegate {
    enum BillingPlan: String, CaseIterable, Identifiable {
        case monthly = "Monthly"
        case annual = "Annual"

        var id: String { rawValue }
    }

    private enum Constants {
        static let fallbackAPIKey = "test_tLWwpGYldPETCFplXsTRbTxdlOI"
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
        case .autoFillAddress, .marketRentSuggestion, .nationwideTaxes, .marketInsights:
            return isPremium
        }
    }

    func configureIfNeeded() {
        guard !configured else { return }

        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedKey = (apiKey?.isEmpty == false) ? apiKey! : Constants.fallbackAPIKey

        guard !resolvedKey.isEmpty else {
            lastErrorMessage = "Missing RevenueCat API key."
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

        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.current
            currentOffering = offering
            availablePackages = offering?.availablePackages ?? []
        } catch {
            lastErrorMessage = "Unable to load subscription options."
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
        return availablePackages.first { pkg in
            normalized.contains(pkg.identifier.lowercased()) ||
            normalized.contains(pkg.storeProduct.productIdentifier.lowercased())
        }
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
