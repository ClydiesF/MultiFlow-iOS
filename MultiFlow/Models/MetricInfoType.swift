import Foundation

enum MetricInfoType: String, Identifiable, CaseIterable, Hashable {
    case netOperatingIncome
    case cashFlow
    case capRate
    case cashOnCash
    case dcr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .netOperatingIncome: return "Net Operating Income (NOI)"
        case .cashFlow: return "Cash Flow"
        case .capRate: return "Cap Rate"
        case .cashOnCash: return "Cash-on-Cash"
        case .dcr: return "Debt Coverage Ratio (DCR)"
        }
    }

    var definition: String {
        glossaryTerm?.definition ?? ""
    }

    var importance: String {
        glossaryTerm?.whyItMatters ?? ""
    }

    var formula: String? {
        glossaryTerm?.formula
    }

    var iconName: String {
        glossaryTerm?.iconSystemName ?? "info.circle"
    }

    var glossaryTerm: GlossaryTerm? {
        GlossaryCatalog.term(for: self)
    }
}
