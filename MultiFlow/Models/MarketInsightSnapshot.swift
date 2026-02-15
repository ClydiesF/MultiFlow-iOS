import Foundation

struct MarketInsightSnapshot: Codable, Equatable, Sendable {
    let rentGrowthYoYPercent: Double
    let daysOnMarket: Int
    let inventoryLevel: String

    var formattedRentGrowth: String {
        let sign = rentGrowthYoYPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", rentGrowthYoYPercent))% YoY"
    }

    var formattedDaysOnMarket: String {
        "\(daysOnMarket) days"
    }
}
