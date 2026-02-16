import SwiftUI

struct MortgageHeroCardView: View {
    let breakdown: MortgageBreakdown
    @Binding var termSelection: Int?
    var defaultTerm: Int
    var onOpenDetails: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var resolvedTerm: Int {
        termSelection ?? defaultTerm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mortgage Estimator")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Monthly-first snapshot")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Color.richBlack.opacity(0.58))
                        .padding(.bottom, 10)
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 52, height: 5)
                }
                Spacer()
                Button {
                    onOpenDetails()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                        Text("Lab")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.68))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow.opacity(0.35))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Mortgage Lab")
            }

            HStack(spacing: 8) {
                termButton(15)
                termButton(20)
                termButton(30)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                metricChip(title: "P&I", value: breakdown.monthlyPrincipal + breakdown.monthlyInterest, a11y: "Principal and interest monthly")
                metricChip(title: "Taxes", value: breakdown.monthlyTaxes, a11y: "Taxes monthly")
                metricChip(title: "Insurance", value: breakdown.monthlyInsurance, a11y: "Insurance monthly")
                metricChip(title: "Total", value: breakdown.monthlyTotal, a11y: "Mortgage total monthly")
            }
        }
    }

    private func termButton(_ year: Int) -> some View {
        let selected = resolvedTerm == year
        return Button {
            termSelection = year
        } label: {
            Text("\(year)y")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(selected ? Color.primaryYellow : Color.richBlack.opacity(0.68))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Color.primaryYellow.opacity(0.14)  : Color.softGray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? Color.primaryYellow.opacity(0.8) : Color.richBlack.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set loan term \(year) years")
    }

    private func metricChip(title: String, value: Double, a11y: String) -> some View {
        Button {
            onOpenDetails()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.56))
                Text(Formatters.currency.string(from: NSNumber(value: value)) ?? "$0")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
        .accessibilityHint("Opens mortgage breakdown details")
    }
}

#Preview {
    struct PreviewHost: View {
        @State var term: Int? = 30
        var body: some View {
            MortgageHeroCardView(
                breakdown: MortgageBreakdown(
                    monthlyPrincipal: 900,
                    monthlyInterest: 1320,
                    monthlyTaxes: 480,
                    monthlyInsurance: 120,
                    monthlyTotal: 2820,
                    annualPrincipal: 10800,
                    annualInterest: 15840,
                    annualTaxes: 5760,
                    annualInsurance: 1440,
                    annualTotal: 33840
                ),
                termSelection: $term,
                defaultTerm: 30
            ) { }
            .padding()
            .background(Color.canvasWhite)
        }
    }

    return PreviewHost()
}
