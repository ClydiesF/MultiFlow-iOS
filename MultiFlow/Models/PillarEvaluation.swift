import Foundation

enum Pillar: String, CaseIterable, Hashable {
    case cashFlow
    case mortgagePaydown
    case equity
    case taxIncentives

    var title: String {
        switch self {
        case .cashFlow:
            return "Cash Flow"
        case .mortgagePaydown:
            return "Mortgage Paydown"
        case .equity:
            return "Equity"
        case .taxIncentives:
            return "Tax Incentives"
        }
    }
}

enum PillarStatus: String, Hashable {
    case met
    case notMet
    case needsInput
    case borderline

    var label: String {
        switch self {
        case .met:
            return "Met"
        case .notMet:
            return "Not Met"
        case .needsInput:
            return "Needs Inputs"
        case .borderline:
            return "Borderline"
        }
    }
}

struct PillarResult: Hashable {
    var pillar: Pillar
    var status: PillarStatus
    var detail: String
    var value: Double?
    var monthlyValue: Double?
    var annualValue: Double?
    var thresholdValue: Double?
}

struct PillarEvaluation: Hashable {
    var results: [PillarResult]

    var metPillars: [Pillar] {
        results.filter { $0.status == .met }.map { $0.pillar }
    }
}
