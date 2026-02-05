import Foundation
import FirebaseFirestore

struct GradeProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var weightCashOnCash: Double
    var weightDcr: Double
    var weightCapRate: Double
    var weightCashFlow: Double
    var weightEquityGain: Double
    var colorHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case name = "Name"
        case weightCashOnCash = "WeightCashOnCash"
        case weightDcr = "WeightDcr"
        case weightCapRate = "WeightCapRate"
        case weightCashFlow = "WeightCashFlow"
        case weightEquityGain = "WeightEquityGain"
        case colorHex = "ColorHex"
    }

    static var defaultProfile: GradeProfile {
        GradeProfile(
            name: "Balanced",
            weightCashOnCash: 30,
            weightDcr: 25,
            weightCapRate: 20,
            weightCashFlow: 15,
            weightEquityGain: 10,
            colorHex: "#FFDD00FF"
        )
    }

    var normalizedWeights: (coc: Double, dcr: Double, cap: Double, cashFlow: Double, equity: Double) {
        let total = weightCashOnCash + weightDcr + weightCapRate + weightCashFlow + weightEquityGain
        let denom = total > 0 ? total : 1
        return (
            coc: weightCashOnCash / denom,
            dcr: weightDcr / denom,
            cap: weightCapRate / denom,
            cashFlow: weightCashFlow / denom,
            equity: weightEquityGain / denom
        )
    }
}
