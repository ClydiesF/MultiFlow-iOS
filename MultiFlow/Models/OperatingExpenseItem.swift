import Foundation

struct OperatingExpenseItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var annualAmount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case annualAmount = "annual_amount"
    }

    init(id: String = UUID().uuidString, name: String, annualAmount: Double) {
        self.id = id
        self.name = name
        self.annualAmount = annualAmount
    }
}
