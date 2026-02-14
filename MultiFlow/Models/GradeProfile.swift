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
    var weightNoi: Double
    var enabledCashOnCash: Bool
    var enabledDcr: Bool
    var enabledCapRate: Bool
    var enabledCashFlow: Bool
    var enabledEquityGain: Bool
    var enabledNoi: Bool
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
        case weightNoi = "weight_noi"
        case enabledCashOnCash = "enabled_cash_on_cash"
        case enabledDcr = "enabled_dcr"
        case enabledCapRate = "enabled_cap_rate"
        case enabledCashFlow = "enabled_cash_flow"
        case enabledEquityGain = "enabled_equity_gain"
        case enabledNoi = "enabled_noi"
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
            weightNoi: 10,
            enabledCashOnCash: true,
            enabledDcr: true,
            enabledCapRate: true,
            enabledCashFlow: true,
            enabledEquityGain: true,
            enabledNoi: true,
            colorHex: "#FFDD00FF"
        )
    }

    init(
        id: String? = nil,
        userId: String? = nil,
        name: String,
        weightCashOnCash: Double,
        weightDcr: Double,
        weightCapRate: Double,
        weightCashFlow: Double,
        weightEquityGain: Double,
        weightNoi: Double = 10,
        enabledCashOnCash: Bool = true,
        enabledDcr: Bool = true,
        enabledCapRate: Bool = true,
        enabledCashFlow: Bool = true,
        enabledEquityGain: Bool = true,
        enabledNoi: Bool = true,
        colorHex: String
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.weightCashOnCash = weightCashOnCash
        self.weightDcr = weightDcr
        self.weightCapRate = weightCapRate
        self.weightCashFlow = weightCashFlow
        self.weightEquityGain = weightEquityGain
        self.weightNoi = weightNoi
        self.enabledCashOnCash = enabledCashOnCash
        self.enabledDcr = enabledDcr
        self.enabledCapRate = enabledCapRate
        self.enabledCashFlow = enabledCashFlow
        self.enabledEquityGain = enabledEquityGain
        self.enabledNoi = enabledNoi
        self.colorHex = colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        weightCashOnCash = try container.decode(Double.self, forKey: .weightCashOnCash)
        weightDcr = try container.decode(Double.self, forKey: .weightDcr)
        weightCapRate = try container.decode(Double.self, forKey: .weightCapRate)
        weightCashFlow = try container.decode(Double.self, forKey: .weightCashFlow)
        weightEquityGain = try container.decode(Double.self, forKey: .weightEquityGain)
        weightNoi = try container.decodeIfPresent(Double.self, forKey: .weightNoi) ?? 10
        enabledCashOnCash = try container.decodeIfPresent(Bool.self, forKey: .enabledCashOnCash) ?? true
        enabledDcr = try container.decodeIfPresent(Bool.self, forKey: .enabledDcr) ?? true
        enabledCapRate = try container.decodeIfPresent(Bool.self, forKey: .enabledCapRate) ?? true
        enabledCashFlow = try container.decodeIfPresent(Bool.self, forKey: .enabledCashFlow) ?? true
        enabledEquityGain = try container.decodeIfPresent(Bool.self, forKey: .enabledEquityGain) ?? true
        enabledNoi = try container.decodeIfPresent(Bool.self, forKey: .enabledNoi) ?? true
        colorHex = try container.decode(String.self, forKey: .colorHex)
    }

    var hasAtLeastOneEnabledCriterion: Bool {
        enabledCashOnCash || enabledDcr || enabledCapRate || enabledCashFlow || enabledEquityGain || enabledNoi
    }

    var enabledCriteriaCount: Int {
        [
            enabledCashOnCash,
            enabledDcr,
            enabledCapRate,
            enabledCashFlow,
            enabledEquityGain,
            enabledNoi
        ].filter { $0 }.count
    }

    var activeNormalizedWeights: (coc: Double, dcr: Double, cap: Double, cashFlow: Double, equity: Double, noi: Double) {
        let activeCashOnCash = enabledCashOnCash ? max(weightCashOnCash, 0) : 0
        let activeDcr = enabledDcr ? max(weightDcr, 0) : 0
        let activeCapRate = enabledCapRate ? max(weightCapRate, 0) : 0
        let activeCashFlow = enabledCashFlow ? max(weightCashFlow, 0) : 0
        let activeEquityGain = enabledEquityGain ? max(weightEquityGain, 0) : 0
        let activeNoi = enabledNoi ? max(weightNoi, 0) : 0
        let total = activeCashOnCash + activeDcr + activeCapRate + activeCashFlow + activeEquityGain + activeNoi
        let denom = total > 0 ? total : 1
        return (
            coc: activeCashOnCash / denom,
            dcr: activeDcr / denom,
            cap: activeCapRate / denom,
            cashFlow: activeCashFlow / denom,
            equity: activeEquityGain / denom,
            noi: activeNoi / denom
        )
    }
}
