import SwiftUI

struct RentRollSummaryView: View {
    let units: [RentUnitInput]

    private var monthlyTotal: Double {
        units.reduce(0) { partial, unit in
            partial + (InputFormatters.parseCurrency(unit.monthlyRent) ?? 0)
        }
    }

    private var annualTotal: Double {
        monthlyTotal * 12.0
    }

    private var totalBeds: Double {
        units.reduce(0) { partial, unit in
            partial + (Double(unit.bedrooms) ?? 0)
        }
    }

    private var totalBaths: Double {
        units.reduce(0) { partial, unit in
            partial + (Double(unit.bathrooms) ?? 0)
        }
    }

    private var totalSquareFeet: Double? {
        let values = units.compactMap { Double($0.squareFeet) }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                summaryCell(
                    title: "Monthly Rent",
                    value: Formatters.currencyTwo.string(from: NSNumber(value: monthlyTotal)) ?? "$0"
                )
                summaryCell(
                    title: "Annual Rent",
                    value: Formatters.currencyTwo.string(from: NSNumber(value: annualTotal)) ?? "$0"
                )
            }

            HStack(spacing: 12) {
                summaryCell(
                    title: "Total Beds",
                    value: Formatters.bedsBaths.string(from: NSNumber(value: totalBeds)) ?? "0"
                )
                summaryCell(
                    title: "Total Baths",
                    value: Formatters.bedsBaths.string(from: NSNumber(value: totalBaths)) ?? "0"
                )
                summaryCell(
                    title: "Total SqFt",
                    value: totalSquareFeet.map(formattedSquareFeet) ?? "-"
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func summaryCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func formattedSquareFeet(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

#Preview {
    VStack(spacing: 16) {
        RentRollSummaryView(
            units: [
                RentUnitInput(
                    monthlyRent: "$1,850.00",
                    unitType: "Unit 1",
                    bedrooms: "2",
                    bathrooms: "1",
                    squareFeet: "900"
                ),
                RentUnitInput(
                    monthlyRent: "$2,050.00",
                    unitType: "Unit 2",
                    bedrooms: "2",
                    bathrooms: "2",
                    squareFeet: "980"
                ),
                RentUnitInput(
                    monthlyRent: "$1,400.00",
                    unitType: "Unit 3",
                    bedrooms: "1",
                    bathrooms: "1",
                    squareFeet: ""
                )
            ]
        )
    }
    .padding(20)
    .background(Color.canvasWhite)
}
