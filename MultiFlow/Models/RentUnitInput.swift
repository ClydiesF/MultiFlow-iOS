import Foundation

struct RentUnitInput: Identifiable, Hashable {
    var id = UUID()
    var monthlyRent: String
    var unitType: String
    var bedrooms: String
    var bathrooms: String
}

struct OperatingExpenseInput: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var annualAmount: String
}
