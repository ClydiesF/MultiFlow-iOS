import SwiftUI

enum MetricInfoType: String, Identifiable {
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
        switch self {
        case .netOperatingIncome:
            return "Net Operating Income (NOI) is annual rental income after vacancy and operating expenses, before mortgage payments."
        case .cashFlow:
            return "Cash flow is the money left over after paying operating expenses and debt service. MultiFlow shows this as monthly and annual views."
        case .capRate:
            return "Cap rate measures the relationship between net operating income (NOI) and purchase price. It shows the unlevered return on the property."
        case .cashOnCash:
            return "Cash-on-cash return measures annual cash flow divided by the cash invested (down payment). It reflects how hard your cash is working."
        case .dcr:
            return "Debt Coverage Ratio (DCR) compares NOI to annual debt service. It shows how comfortably the property covers its mortgage payments."
        }
    }

    var importance: String {
        switch self {
        case .netOperatingIncome:
            return "NOI is the foundation for many real-estate metrics. Strong NOI supports better valuation, stronger DCR, and safer financing."
        case .cashFlow:
            return "Positive and durable cash flow is core to deal quality because it drives monthly safety, reinvestment capacity, and portfolio resilience."
        case .capRate:
            return "Higher cap rates generally mean stronger income relative to price, but must be balanced against risk and market norms."
        case .cashOnCash:
            return "A higher cash-on-cash return means more cashflow per dollar invested, which helps compare deals of different sizes."
        case .dcr:
            return "Lenders often require a minimum DCR; stronger ratios reduce default risk and improve financing options."
        }
    }

    var iconName: String {
        switch self {
        case .netOperatingIncome:
            return "building.2"
        case .cashFlow:
            return "chart.line.uptrend.xyaxis"
        case .capRate:
            return "percent"
        case .cashOnCash:
            return "dollarsign.circle"
        case .dcr:
            return "shield.checkerboard"
        }
    }
}

struct MetricInfoSheet: View {
    let metric: MetricInfoType
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(Color.primaryYellow)
                                .frame(width: 36, height: 6)
                            Text("Metric Guide")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.6))
                        }

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.primaryYellow.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                Image(systemName: metric.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.richBlack)
                            }
                            Text(metric.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.richBlack)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Definition")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Text(metric.definition)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.8))
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Why It Matters")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Text(metric.importance)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.8))
                        }
                        .cardStyle()

                        Button("Done") { dismiss() }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 8)
                    }
                    .padding(24)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appear)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { appear = true }
    }
}

#Preview {
    MetricInfoSheet(metric: .capRate)
}
