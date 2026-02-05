import Foundation

struct MetricsEngine {
    // Assumes a 30-year fixed loan term for amortization.
    static let defaultLoanTermYears: Double = 30
    static let operatingExpenseRate: Double = 0.35

    static func computeMetrics(
        purchasePrice: Double,
        downPaymentPercent: Double,
        interestRate: Double,
        annualTaxes: Double,
        annualInsurance: Double,
        loanTermYears: Double,
        rentRoll: [RentUnitInput],
        useStandardOperatingExpense: Bool,
        operatingExpenseRateOverride: Double,
        operatingExpenses: [OperatingExpenseInput]
    ) -> DealMetrics {
        let totalAnnualRent = rentRoll
            .compactMap { Double($0.monthlyRent) }
            .reduce(0, +) * 12.0

        let expenseRate = operatingExpenseRateOverride
        let expenseTotal = operatingExpenses
            .compactMap { Double($0.annualAmount) }
            .reduce(0, +)

        let netOperatingIncome = useStandardOperatingExpense
            ? totalAnnualRent * (1.0 - expenseRate)
            : totalAnnualRent - expenseTotal

        let loanAmount = max(purchasePrice * (1.0 - downPaymentPercent / 100.0), 0)
        let annualDebtService = annualMortgagePayment(
            loanAmount: loanAmount,
            annualInterestRate: interestRate,
            years: loanTermYears
        )

        // Annual cash flow subtracts debt service and taxes/insurance from NOI.
        let annualCashFlow = netOperatingIncome - annualDebtService - annualTaxes - annualInsurance

        let downPayment = max(purchasePrice * (downPaymentPercent / 100.0), 0.0001)
        let cashOnCash = annualCashFlow / downPayment

        let capRate = purchasePrice > 0 ? netOperatingIncome / purchasePrice : 0
        let dcr = annualDebtService > 0 ? netOperatingIncome / annualDebtService : 0

        let grade = gradeFor(cashOnCash: cashOnCash, dcr: dcr)

        return DealMetrics(
            totalAnnualRent: totalAnnualRent,
            netOperatingIncome: netOperatingIncome,
            capRate: capRate,
            annualDebtService: annualDebtService,
            annualCashFlow: annualCashFlow,
            cashOnCash: cashOnCash,
            debtCoverageRatio: dcr,
            grade: grade
        )
    }

    static func computeMetrics(property: Property) -> DealMetrics? {
        guard
            let downPaymentPercent = property.downPaymentPercent,
            let interestRate = property.interestRate
        else {
            return nil
        }

        let rentInputs = property.rentRoll.map {
            RentUnitInput(
                monthlyRent: String($0.monthlyRent),
                unitType: $0.unitType,
                bedrooms: String($0.bedrooms),
                bathrooms: String($0.bathrooms)
            )
        }

        let useStandard = property.useStandardOperatingExpense ?? true
        let expenseRate = (property.operatingExpenseRate ?? operatingExpenseRate) / 100.0
        let expenseInputs = property.operatingExpenses?.map {
            OperatingExpenseInput(name: $0.name, annualAmount: String($0.annualAmount))
        } ?? []

        let taxes = property.annualTaxes ?? (property.annualTaxesInsurance ?? 0)
        let insurance = property.annualInsurance ?? 0
        let termYears = Double(property.loanTermYears ?? Int(defaultLoanTermYears))

        return computeMetrics(
            purchasePrice: property.purchasePrice,
            downPaymentPercent: downPaymentPercent,
            interestRate: interestRate,
            annualTaxes: taxes,
            annualInsurance: insurance,
            loanTermYears: termYears,
            rentRoll: rentInputs,
            useStandardOperatingExpense: useStandard,
            operatingExpenseRateOverride: expenseRate,
            operatingExpenses: expenseInputs
        )
    }

    static func gradeFor(cashOnCash: Double, dcr: Double) -> Grade {
        if cashOnCash > 0.10, dcr > 1.35 {
            return .a
        }

        if cashOnCash >= 0.07, cashOnCash <= 0.10, dcr >= 1.25, dcr <= 1.35 {
            return .b
        }

        if cashOnCash >= 0.04, cashOnCash < 0.07, dcr >= 1.15, dcr < 1.25 {
            return .c
        }

        return .dOrF
    }

    static func weightedGrade(
        metrics: DealMetrics,
        purchasePrice: Double,
        annualPrincipalPaydown: Double,
        appreciationRate: Double,
        cashflowBreakEvenThreshold: Double,
        profile: GradeProfile
    ) -> Grade {
        let monthlyCashFlow = metrics.annualCashFlow / 12.0
        let breakEvenAnnual = max(cashflowBreakEvenThreshold, 0) * 12.0

        let annualAppreciation = max(purchasePrice * (appreciationRate / 100.0), 0)
        let equityGain = annualPrincipalPaydown + annualAppreciation

        let cocScore = piecewiseScore(metrics.cashOnCash, points: [
            (0.00, 0), (0.08, 60), (0.12, 85), (0.15, 100)
        ])
        let dcrScore = piecewiseScore(metrics.debtCoverageRatio, points: [
            (1.00, 0), (1.20, 60), (1.35, 85), (1.50, 100)
        ])
        let capScore = piecewiseScore(metrics.capRate, points: [
            (0.03, 0), (0.06, 60), (0.08, 85), (0.10, 100)
        ])

        let cashFlowScore = piecewiseScore(metrics.annualCashFlow, points: [
            (0, 0), (breakEvenAnnual, 50), (breakEvenAnnual + 5_000, 80), (breakEvenAnnual + 10_000, 100)
        ])

        let equityScore = piecewiseScore(equityGain / max(purchasePrice, 1), points: [
            (0.00, 0), (0.02, 60), (0.04, 85), (0.06, 100)
        ])

        let w = profile.normalizedWeights
        let total = cocScore * w.coc +
            dcrScore * w.dcr +
            capScore * w.cap +
            cashFlowScore * w.cashFlow +
            equityScore * w.equity

        return gradeFromScore(total)
    }

    private static func gradeFromScore(_ score: Double) -> Grade {
        switch score {
        case 85...: return .a
        case 70..<85: return .b
        case 55..<70: return .c
        default: return .dOrF
        }
    }

    private static func piecewiseScore(_ value: Double, points: [(Double, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if value <= first.0 { return first.1 }
        if value >= last.0 { return last.1 }

        for idx in 0..<(points.count - 1) {
            let (x1, y1) = points[idx]
            let (x2, y2) = points[idx + 1]
            if value >= x1 && value <= x2 {
                let t = (value - x1) / max(x2 - x1, 0.000001)
                return y1 + (y2 - y1) * t
            }
        }
        return 0
    }

    private static func annualMortgagePayment(
        loanAmount: Double,
        annualInterestRate: Double,
        years: Double
    ) -> Double {
        if loanAmount <= 0 { return 0 }
        let monthlyRate = (annualInterestRate / 100.0) / 12.0
        let numberOfPayments = years * 12.0

        if monthlyRate == 0 {
            return (loanAmount / numberOfPayments) * 12.0
        }

        let numerator = monthlyRate * pow(1 + monthlyRate, numberOfPayments)
        let denominator = pow(1 + monthlyRate, numberOfPayments) - 1
        let monthlyPayment = loanAmount * (numerator / denominator)
        return monthlyPayment * 12.0
    }

    static func mortgageBreakdown(
        purchasePrice: Double,
        downPaymentPercent: Double,
        interestRate: Double,
        loanTermYears: Double,
        annualTaxes: Double,
        annualInsurance: Double
    ) -> MortgageBreakdown? {
        guard purchasePrice > 0, loanTermYears > 0 else { return nil }
        let loanAmount = max(purchasePrice * (1.0 - downPaymentPercent / 100.0), 0)
        let annualPI = annualMortgagePayment(
            loanAmount: loanAmount,
            annualInterestRate: interestRate,
            years: loanTermYears
        )
        let monthlyPI = annualPI / 12.0
        let monthlyRate = (interestRate / 100.0) / 12.0

        var balance = loanAmount
        var annualInterest: Double = 0
        var annualPrincipal: Double = 0

        for _ in 0..<12 {
            let interest = balance * monthlyRate
            let principal = max(monthlyPI - interest, 0)
            annualInterest += interest
            annualPrincipal += principal
            balance = max(balance - principal, 0)
        }

        let monthlyTaxes = annualTaxes / 12.0
        let monthlyInsurance = annualInsurance / 12.0

        return MortgageBreakdown(
            monthlyPrincipal: annualPrincipal / 12.0,
            monthlyInterest: annualInterest / 12.0,
            monthlyTaxes: monthlyTaxes,
            monthlyInsurance: monthlyInsurance,
            monthlyTotal: monthlyPI + monthlyTaxes + monthlyInsurance,
            annualPrincipal: annualPrincipal,
            annualInterest: annualInterest,
            annualTaxes: annualTaxes,
            annualInsurance: annualInsurance,
            annualTotal: annualPI + annualTaxes + annualInsurance
        )
    }
}
