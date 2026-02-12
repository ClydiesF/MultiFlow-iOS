import Foundation

struct RentUnitInput: Identifiable, Hashable {
    var id = UUID()
    var monthlyRent: String
    var unitType: String
    var bedrooms: String
    var bathrooms: String
    var squareFeet: String

    init(
        id: UUID = UUID(),
        monthlyRent: String,
        unitType: String,
        bedrooms: String,
        bathrooms: String,
        squareFeet: String = ""
    ) {
        self.id = id
        self.monthlyRent = monthlyRent
        self.unitType = unitType
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.squareFeet = squareFeet
    }
}

struct OperatingExpenseInput: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var annualAmount: String
}
