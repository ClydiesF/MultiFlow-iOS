import Foundation

struct MortgageBreakdown: Hashable {
    var monthlyPrincipal: Double
    var monthlyInterest: Double
    var monthlyTaxes: Double
    var monthlyInsurance: Double
    var monthlyTotal: Double
    var annualPrincipal: Double
    var annualInterest: Double
    var annualTaxes: Double
    var annualInsurance: Double
    var annualTotal: Double
}
