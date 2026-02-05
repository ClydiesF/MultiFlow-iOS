import Foundation

struct DealMetrics: Hashable {
    var totalAnnualRent: Double
    var netOperatingIncome: Double
    var capRate: Double
    var annualDebtService: Double
    var annualCashFlow: Double
    var cashOnCash: Double
    var debtCoverageRatio: Double
    var grade: Grade
}

enum Grade: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case dOrF = "D/F"
}
