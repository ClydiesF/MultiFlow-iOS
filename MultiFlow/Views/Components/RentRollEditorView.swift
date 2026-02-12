import SwiftUI

enum RentRollEditorStyle {
    case compact
    case full
}

struct RentRollEditorView: View {
    @Binding var units: [RentUnitInput]
    var style: RentRollEditorStyle = .full
    var allowsUnitType: Bool = true
    var requiresValidRentRow: Bool = false
    var onValidationChange: ((Bool) -> Void)? = nil

    @State private var applyRentToAll = ""

    private var hasValidRentRow: Bool {
        Self.hasAtLeastOneValidRentRow(units)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rent Roll")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Button("Add Unit") {
                    units.append(RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: ""))
                    emitValidation()
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
            }

            HStack(spacing: 8) {
                LabeledTextField(title: "Apply Rent To All", text: $applyRentToAll, keyboard: .decimalPad)
                    .onChange(of: applyRentToAll) { _, newValue in
                        applyRentToAll = InputFormatters.formatCurrencyLive(newValue)
                    }
                Button("Apply") {
                    guard !applyRentToAll.isEmpty else { return }
                    for index in units.indices {
                        units[index].monthlyRent = applyRentToAll
                    }
                    emitValidation()
                }
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.richBlack.opacity(0.2), lineWidth: 1)
                )
            }

            ForEach($units) { $unit in
                VStack(spacing: 10) {
                    if allowsUnitType {
                        LabeledTextField(title: "Unit Type", text: $unit.unitType, keyboard: .default)
                    }

                    HStack(spacing: 8) {
                        LabeledTextField(title: "Monthly Rent", text: $unit.monthlyRent, keyboard: .decimalPad)
                            .onChange(of: unit.monthlyRent) { _, newValue in
                                unit.monthlyRent = InputFormatters.formatCurrencyLive(newValue)
                                emitValidation()
                            }

                        LabeledTextField(title: "SqFt (Optional)", text: $unit.squareFeet, keyboard: .numberPad)
                            .onChange(of: unit.squareFeet) { _, newValue in
                                unit.squareFeet = InputFormatters.sanitizeDecimal(newValue)
                            }
                    }

                    HStack(spacing: 8) {
                        LabeledTextField(title: "Beds", text: $unit.bedrooms, keyboard: .numberPad)
                            .onChange(of: unit.bedrooms) { _, newValue in
                                unit.bedrooms = InputFormatters.sanitizeDecimal(newValue)
                            }

                        LabeledTextField(title: "Baths", text: $unit.bathrooms, keyboard: .numberPad)
                            .onChange(of: unit.bathrooms) { _, newValue in
                                unit.bathrooms = InputFormatters.sanitizeDecimal(newValue)
                            }
                    }

                    if units.count > 1 {
                        Button("Remove Unit") {
                            units.removeAll { $0.id == unit.id }
                            if units.isEmpty {
                                units = [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")]
                            }
                            emitValidation()
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
                .padding(style == .compact ? 10 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.softGray)
                )

                if unit.id != units.last?.id {
                    Divider()
                        .background(Color.richBlack.opacity(0.08))
                        .padding(.vertical, 4)
                }
            }

            if requiresValidRentRow && !hasValidRentRow {
                Text("Add at least one unit with monthly rent to continue.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.red)
            }

            RentRollSummaryView(units: units)
        }
        .onAppear {
            if units.isEmpty {
                units = [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")]
            }
            emitValidation()
        }
        .onChange(of: units) { _, _ in
            emitValidation()
        }
    }

    private func emitValidation() {
        onValidationChange?(hasValidRentRow)
    }
}

extension RentRollEditorView {
    static func hasAtLeastOneValidRentRow(_ units: [RentUnitInput]) -> Bool {
        units.contains { (InputFormatters.parseCurrency($0.monthlyRent) ?? 0) > 0 }
    }

    static func validUnits(from units: [RentUnitInput]) -> [RentUnit] {
        units.compactMap { unit in
            guard let rent = InputFormatters.parseCurrency(unit.monthlyRent), rent > 0 else {
                return nil
            }
            let beds = Double(unit.bedrooms) ?? 0
            let baths = Double(unit.bathrooms) ?? 0
            let sqft = Double(unit.squareFeet).flatMap { $0 > 0 ? $0 : nil }
            let normalizedType = unit.unitType.trimmingCharacters(in: .whitespacesAndNewlines)

            return RentUnit(
                id: unit.id.uuidString,
                monthlyRent: rent,
                unitType: normalizedType.isEmpty ? "Unit" : normalizedType,
                bedrooms: beds,
                bathrooms: baths,
                squareFeet: sqft
            )
        }
    }
}

#Preview {
    RentRollEditorPreviewHost()
}

private struct RentRollEditorPreviewHost: View {
    @State private var units: [RentUnitInput] = [
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
            monthlyRent: "",
            unitType: "Unit 3",
            bedrooms: "",
            bathrooms: "",
            squareFeet: ""
        )
    ]
    @State private var isValid = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RentRollEditorView(
                    units: $units,
                    style: .full,
                    allowsUnitType: true,
                    requiresValidRentRow: true
                ) { valid in
                    isValid = valid
                }

                Text("Has valid rent row: \(isValid ? "Yes" : "No")")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
            }
            .padding(20)
        }
        .background(Color.canvasWhite)
    }
}
