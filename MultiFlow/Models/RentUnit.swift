import Foundation

struct RentUnit: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var monthlyRent: Double
    var unitType: String
    var bedrooms: Double
    var bathrooms: Double

    enum CodingKeys: String, CodingKey {
        case id
        case monthlyRent = "monthly_rent"
        case unitType = "unit_type"
        case bedrooms
        case bathrooms
    }

    init(id: String = UUID().uuidString, monthlyRent: Double, unitType: String, bedrooms: Double, bathrooms: Double) {
        self.id = id
        self.monthlyRent = monthlyRent
        self.unitType = unitType
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
    }
}
