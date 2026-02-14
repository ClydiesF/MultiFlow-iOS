import Foundation

enum GlossaryCatalog {
    static let allTerms: [GlossaryTerm] = [
        GlossaryTerm(
            id: "noi",
            title: "Net Operating Income (NOI)",
            aliases: ["NOI", "Net Income"],
            category: .coreMetrics,
            definition: "Net Operating Income (NOI) is annual rental income after vacancy and operating expenses, before mortgage payments.",
            whyItMatters: "NOI is the foundation for many real-estate metrics. Strong NOI supports better valuation, stronger DCR, and safer financing.",
            formula: "NOI = Effective Gross Rent - Operating Expenses",
            iconSystemName: "building.2",
            relatedMetrics: [.netOperatingIncome, .dcr, .capRate]
        ),
        GlossaryTerm(
            id: "cash-flow",
            title: "Cash Flow",
            aliases: ["Monthly Cash Flow", "Annual Cash Flow"],
            category: .coreMetrics,
            definition: "Cash flow is the money left over after paying operating expenses and debt service. MultiFlow shows this as monthly and annual views.",
            whyItMatters: "Positive and durable cash flow is core to deal quality because it drives monthly safety, reinvestment capacity, and portfolio resilience.",
            formula: "Cash Flow = NOI - Annual Debt Service",
            iconSystemName: "chart.line.uptrend.xyaxis",
            relatedMetrics: [.cashFlow]
        ),
        GlossaryTerm(
            id: "cap-rate",
            title: "Cap Rate",
            aliases: ["Capitalization Rate", "Cap"],
            category: .coreMetrics,
            definition: "Cap rate measures the relationship between net operating income (NOI) and purchase price. It shows the unlevered return on the property.",
            whyItMatters: "Higher cap rates generally mean stronger income relative to price, but must be balanced against risk and market norms.",
            formula: "Cap Rate = NOI / Purchase Price",
            iconSystemName: "percent",
            relatedMetrics: [.capRate]
        ),
        GlossaryTerm(
            id: "cash-on-cash",
            title: "Cash-on-Cash",
            aliases: ["CoC", "Cash Return"],
            category: .coreMetrics,
            definition: "Cash-on-cash return measures annual cash flow divided by the cash invested (down payment). It reflects how hard your cash is working.",
            whyItMatters: "A higher cash-on-cash return means more cashflow per dollar invested, which helps compare deals of different sizes.",
            formula: "CoC = Annual Cash Flow / Cash Invested",
            iconSystemName: "dollarsign.circle",
            relatedMetrics: [.cashOnCash]
        ),
        GlossaryTerm(
            id: "dcr",
            title: "Debt Coverage Ratio (DCR/DSCR)",
            aliases: ["DCR", "DSCR", "Debt Service Coverage Ratio"],
            category: .coreMetrics,
            definition: "Debt Coverage Ratio compares NOI to annual debt service. It shows how comfortably the property covers its mortgage payments.",
            whyItMatters: "Lenders often require a minimum DCR; stronger ratios reduce default risk and improve financing options.",
            formula: "DCR = NOI / Annual Debt Service",
            iconSystemName: "shield.checkerboard",
            relatedMetrics: [.dcr]
        ),
        GlossaryTerm(
            id: "cash-to-close",
            title: "Cash to Close",
            aliases: ["Upfront Cash", "Total Cash Needed"],
            category: .financing,
            definition: "Cash to close is the total upfront cash needed to acquire the deal, including down payment, closing costs, and reserves.",
            whyItMatters: "It determines whether a deal is actually fundable for your current liquidity and affects your cash-on-cash return.",
            formula: "Cash to Close = Down Payment + Closing Costs + Reserve Contributions",
            iconSystemName: "wallet.bifold",
            relatedMetrics: []
        ),
        GlossaryTerm(
            id: "debt-service",
            title: "Debt Service",
            aliases: ["Annual Debt Service", "Mortgage Payments"],
            category: .financing,
            definition: "Debt service is the total of principal and interest payments over a period, usually shown annually in underwriting.",
            whyItMatters: "Debt service directly impacts DCR and cash flow. Higher debt service can quickly push a deal below lender thresholds.",
            formula: "Debt Service = Principal Payments + Interest Payments",
            iconSystemName: "banknote",
            relatedMetrics: [.dcr, .cashFlow]
        ),
        GlossaryTerm(
            id: "pi",
            title: "Principal & Interest (P&I)",
            aliases: ["P&I", "Mortgage P&I"],
            category: .financing,
            definition: "P&I is the core mortgage payment made up of principal repayment and interest expense, excluding taxes and insurance.",
            whyItMatters: "P&I is usually the largest fixed monthly outflow in leveraged deals and heavily influences monthly total payment.",
            formula: "Monthly Payment = Principal + Interest (+ Taxes + Insurance when escrowed)",
            iconSystemName: "creditcard",
            relatedMetrics: [.cashFlow, .dcr]
        ),
        GlossaryTerm(
            id: "gross-effective-rent",
            title: "Gross Rent / Effective Rent",
            aliases: ["Gross Rent", "Effective Gross Income", "EGI"],
            category: .operatingExpenses,
            definition: "Gross rent is total scheduled rent before vacancy. Effective rent reflects vacancy and collection loss assumptions.",
            whyItMatters: "Using effective rent creates more realistic underwriting and prevents overstating NOI and cash flow.",
            formula: "Effective Rent = Gross Scheduled Rent x (1 - Vacancy Rate)",
            iconSystemName: "building.columns",
            relatedMetrics: [.netOperatingIncome, .cashFlow]
        ),
        GlossaryTerm(
            id: "operating-expense-ratio",
            title: "Operating Expense Ratio (Simple Mode)",
            aliases: ["OER", "Expense Ratio", "Simple Expense Mode"],
            category: .operatingExpenses,
            definition: "Operating Expense Ratio is a blended percentage of effective rent used to estimate annual operating expenses quickly.",
            whyItMatters: "Simple mode speeds up underwriting and supports fast deal screening before entering line-item detail.",
            formula: "Operating Expenses = Effective Rent x Expense Ratio",
            iconSystemName: "slider.horizontal.3",
            relatedMetrics: [.netOperatingIncome, .cashFlow]
        ),
        GlossaryTerm(
            id: "provisional-estimate",
            title: "Estimate (Provisional Analysis)",
            aliases: ["Provisional", "Fast Estimate"],
            category: .strategy,
            definition: "A provisional estimate means some advanced inputs are still defaulted, so output is directional rather than fully underwritten.",
            whyItMatters: "This lets you capture opportunities fast while preserving a clear path to full analysis quality later.",
            formula: nil,
            iconSystemName: "clock.badge.exclamationmark",
            relatedMetrics: []
        )
    ]

    static func term(for metric: MetricInfoType) -> GlossaryTerm? {
        allTerms.first(where: { $0.relatedMetrics.contains(metric) })
    }

    static func filter(query: String) -> [GlossaryTerm] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allTerms }
        let needle = trimmed.lowercased()

        return allTerms.filter { term in
            term.title.lowercased().contains(needle)
            || term.aliases.contains(where: { $0.lowercased().contains(needle) })
            || term.definition.lowercased().contains(needle)
            || term.whyItMatters.lowercased().contains(needle)
            || (term.formula?.lowercased().contains(needle) ?? false)
        }
    }

    static func groupedTerms(matching query: String) -> [(category: GlossaryCategory, terms: [GlossaryTerm])] {
        let filtered = filter(query: query)
        let grouped = Dictionary(grouping: filtered, by: \.category)

        return grouped
            .map { (category: $0.key, terms: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.category.sortOrder < $1.category.sortOrder }
    }
}
