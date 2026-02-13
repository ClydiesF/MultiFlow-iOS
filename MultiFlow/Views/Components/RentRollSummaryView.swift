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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                summaryPill(
                    title: "Monthly",
                    value: Formatters.currencyTwo.string(from: NSNumber(value: monthlyTotal)) ?? "$0"
                )
                summaryPill(
                    title: "Annual",
                    value: Formatters.currencyTwo.string(from: NSNumber(value: annualTotal)) ?? "$0"
                )
                summaryPill(
                    title: "Beds",
                    value: Formatters.bedsBaths.string(from: NSNumber(value: totalBeds)) ?? "0"
                )
                summaryPill(
                    title: "Baths",
                    value: Formatters.bedsBaths.string(from: NSNumber(value: totalBaths)) ?? "0"
                )
                summaryPill(
                    title: "SqFt",
                    value: totalSquareFeet.map(formattedSquareFeet) ?? "-"
                )
            }
            .padding(.horizontal, 1)
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
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
