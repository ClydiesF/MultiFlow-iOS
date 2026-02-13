import Foundation

enum GlossaryCategory: String, CaseIterable, Hashable {
    case coreMetrics
    case financing
    case operatingExpenses
    case strategy

    var displayName: String {
        switch self {
        case .coreMetrics: return "Core Metrics"
        case .financing: return "Financing"
        case .operatingExpenses: return "Operations & Expenses"
        case .strategy: return "Strategy"
        }
    }

    var sortOrder: Int {
        switch self {
        case .coreMetrics: return 0
        case .financing: return 1
        case .operatingExpenses: return 2
        case .strategy: return 3
        }
    }
}

struct GlossaryTerm: Identifiable, Hashable {
    let id: String
    let title: String
    let aliases: [String]
    let category: GlossaryCategory
    let definition: String
    let whyItMatters: String
    let formula: String?
    let iconSystemName: String
    let relatedMetrics: [MetricInfoType]
}
