import SwiftUI
import Charts

struct MortgageDonutChart: View {
    let breakdown: MortgageBreakdown

    private var data: [MortgageSlice] {
        [
            MortgageSlice(label: "Principal", value: breakdown.annualPrincipal, color: .primaryYellow),
            MortgageSlice(label: "Interest", value: breakdown.annualInterest, color: .richBlack.opacity(0.7)),
            MortgageSlice(label: "Taxes", value: breakdown.annualTaxes, color: .softGray),
            MortgageSlice(label: "Insurance", value: breakdown.annualInsurance, color: .richBlack.opacity(0.3))
        ].filter { $0.value > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart(data) { slice in
                SectorMark(
                    angle: .value("Amount", slice.value),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(slice.color)
            }
            .chartLegend(.hidden)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(data) { slice in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        Spacer()
                        Text(Formatters.currency.string(from: NSNumber(value: slice.value)) ?? "$0")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.7))
                    }
                }
            }
        }
    }
}

private struct MortgageSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

#Preview {
    MortgageDonutChart(breakdown: MortgageBreakdown(
        monthlyPrincipal: 600,
        monthlyInterest: 400,
        monthlyTaxes: 200,
        monthlyInsurance: 100,
        monthlyTotal: 1300,
        annualPrincipal: 7200,
        annualInterest: 4800,
        annualTaxes: 2400,
        annualInsurance: 1200,
        annualTotal: 15600
    ))
    .padding()
}
