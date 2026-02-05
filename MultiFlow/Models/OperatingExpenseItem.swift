import Foundation
import FirebaseFirestore

struct OperatingExpenseItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var annualAmount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name = "Name"
        case annualAmount = "AnnualAmount"
    }

    init(id: String = UUID().uuidString, name: String, annualAmount: Double) {
        self.id = id
        self.name = name
        self.annualAmount = annualAmount
    }
}
