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

    var shortTitle: String {
        switch self {
        case .cashFlow:
            return "Cash Flow"
        case .mortgagePaydown:
            return "Paydown"
        case .equity:
            return "Equity"
        case .taxIncentives:
            return "Tax"
        }
    }

    var iconSystemName: String {
        switch self {
        case .cashFlow:
            return "dollarsign.circle.fill"
        case .mortgagePaydown:
            return "banknote.fill"
        case .equity:
            return "chart.line.uptrend.xyaxis.circle.fill"
        case .taxIncentives:
            return "percent"
        }
    }

    var accessibilityLabel: String {
        title
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

    var isMetForDisplay: Bool {
        status == .met
    }
}

extension PillarResult: Identifiable {
    var id: String { pillar.rawValue }
}

struct PillarEvaluation: Hashable {
    var results: [PillarResult]

    var metPillars: [Pillar] {
        results.filter { $0.status == .met }.map { $0.pillar }
    }
}
