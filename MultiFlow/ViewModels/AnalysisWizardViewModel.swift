import Foundation
import Combine

enum AnalysisWizardField: Hashable {
    case address
    case purchasePrice
    case propertyType
    case exactUnitsForTenPlus
    case renoBudget
    case interestRate
    case city
    case state
    case zip
    case taxes
    case marginalTaxRate
    case landValuePercent
}

@MainActor
final class AnalysisWizardViewModel: ObservableObject {
    @Published var stepIndex = 0

    @Published var address = ""
    @Published var city = ""
    @Published var state = ""
    @Published var zipCode = ""
    @Published var purchasePrice = ""
    @Published var propertyType: PropertyType?
    @Published var exactUnitsForTenPlus = ""
    @Published var renoBudget = ""
    @Published var downPaymentPercent = 25.0
    @Published var interestRate = "6.50"
    @Published var loanTermYears = 30
    @Published var annualTaxes = ""

    var canProceedToNextStep: Bool {
        missingFieldsForCurrentStep().isEmpty
    }

    func missingFieldsForCurrentStep() -> Set<AnalysisWizardField> {
        switch stepIndex {
        case 0:
            var missing = Set<AnalysisWizardField>()
            if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.address) }
            if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.city) }
            if state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.state) }
            if zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.zip) }
            if (InputFormatters.parseCurrency(purchasePrice) ?? 0) <= 0 { missing.insert(.purchasePrice) }
            if propertyType == nil { missing.insert(.propertyType) }
            if propertyType == .tenPlus && (Int(exactUnitsForTenPlus) ?? 0) < 10 {
                missing.insert(.exactUnitsForTenPlus)
            }
            return missing
        case 1:
            var missing = Set<AnalysisWizardField>()
            let isPaidOff = downPaymentPercent >= 100
            if !isPaidOff && (Double(interestRate) ?? 0) <= 0 { missing.insert(.interestRate) }
            return missing
        default:
            return []
        }
    }

    func firstEmptyFieldForCurrentStep() -> AnalysisWizardField? {
        switch stepIndex {
        case 0:
            if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .address }
            if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .city }
            if state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .state }
            if zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .zip }
            if (InputFormatters.parseCurrency(purchasePrice) ?? 0) <= 0 { return .purchasePrice }
            if propertyType == nil { return .propertyType }
            if propertyType == .tenPlus && (Int(exactUnitsForTenPlus) ?? 0) < 10 { return .exactUnitsForTenPlus }
            return nil
        case 1:
            let isPaidOff = downPaymentPercent >= 100
            if isPaidOff { return nil }
            return (Double(interestRate) ?? 0) > 0 ? nil : .interestRate
        default:
            return nil
        }
    }

    var resolvedUnitCount: Int? {
        guard let propertyType else { return nil }
        switch propertyType {
        case .tenPlus:
            let value = Int(exactUnitsForTenPlus) ?? 0
            return value >= 10 ? value : nil
        default:
            return propertyType.defaultUnits
        }
    }
}

enum PropertyType: String, CaseIterable, Identifiable {
    case singleFamily
    case duplex
    case triplex
    case fourplex
    case fiveToTen
    case tenPlus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleFamily: return "Single-Family"
        case .duplex: return "Duplex"
        case .triplex: return "Triplex"
        case .fourplex: return "Fourplex"
        case .fiveToTen: return "5-10 Units"
        case .tenPlus: return "10+"
        }
    }

    var symbol: String {
        switch self {
        case .singleFamily: return "house.fill"
        case .duplex: return "building.2.fill"
        case .triplex: return "building.2.crop.circle.fill"
        case .fourplex: return "building.columns.fill"
        case .fiveToTen: return "building.2.crop.circle"
        case .tenPlus: return "building.2"
        }
    }

    var isCommercial: Bool {
        self == .fiveToTen || self == .tenPlus
    }

    var defaultUnits: Int? {
        switch self {
        case .singleFamily: return 1
        case .duplex: return 2
        case .triplex: return 3
        case .fourplex: return 4
        case .fiveToTen: return 8
        case .tenPlus: return nil
        }
    }
}
