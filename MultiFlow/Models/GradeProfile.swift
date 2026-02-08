import Foundation

struct GradeProfile: Identifiable, Codable, Hashable {
    var id: String?
    var userId: String?
    var name: String
    var weightCashOnCash: Double
    var weightDcr: Double
    var weightCapRate: Double
    var weightCashFlow: Double
    var weightEquityGain: Double
    var colorHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case weightCashOnCash = "weight_cash_on_cash"
        case weightDcr = "weight_dcr"
        case weightCapRate = "weight_cap_rate"
        case weightCashFlow = "weight_cash_flow"
        case weightEquityGain = "weight_equity_gain"
        case colorHex = "color_hex"
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
