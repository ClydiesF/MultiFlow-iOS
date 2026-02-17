import Foundation

struct MarketInsightSnapshot: Codable, Equatable, Sendable {
    let medianRent: Double
    let averageRent: Double
    let rentGrowthYoYPercent: Double
    let daysOnMarket: Int
    let newListings: Int
    let totalListings: Int
    let inventoryLevel: String

    var formattedMedianRent: String {
        Formatters.currency.string(from: NSNumber(value: medianRent)) ?? "$0"
    }

    var formattedAverageRent: String {
        Formatters.currency.string(from: NSNumber(value: averageRent)) ?? "$0"
    }

    var formattedRentGrowth: String {
        let sign = rentGrowthYoYPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", rentGrowthYoYPercent))% YoY"
    }

    var formattedDaysOnMarket: String {
        "\(daysOnMarket) days"
    }

    var formattedListingsActivity: String {
        "\(newListings) new / \(totalListings) active"
    }
}
