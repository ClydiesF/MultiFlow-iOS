import Foundation

enum FeatureType: String, CaseIterable, Identifiable {
    case autoFillAddress
    case marketRentSuggestion
    case nationwideTaxes
    case marketInsights
    case dealRooms
    case offerTracker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .autoFillAddress:
            return "Auto-Fill Address"
        case .marketRentSuggestion:
            return "Market Rent Suggestion"
        case .nationwideTaxes:
            return "Nationwide Taxes"
        case .marketInsights:
            return "Market Insights"
        case .dealRooms:
            return "Deal Rooms"
        case .offerTracker:
            return "Offer Tracker"
        }
    }
}
