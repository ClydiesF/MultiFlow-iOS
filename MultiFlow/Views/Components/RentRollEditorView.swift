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
    @State private var expandedUnitIDs: Set<UUID> = []
    @State private var showSquareFeet = false
    @FocusState private var focusedRentUnitID: UUID?

    private var hasValidRentRow: Bool {
        Self.hasAtLeastOneValidRentRow(units)
    }

    private var rowPadding: CGFloat {
        style == .compact ? 10 : 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            quickActionsRow

            ForEach(Array(units.enumerated()), id: \.element.id) { index, unit in
                unitRow(index: index, unit: unit)
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
            if let firstID = units.first?.id {
                expandedUnitIDs.insert(firstID)
            }
            showSquareFeet = units.contains { !$0.squareFeet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            emitValidation()
        }
        .onChange(of: units) { _, newValue in
            let currentIDs = Set(newValue.map(\.id))
            expandedUnitIDs = expandedUnitIDs.intersection(currentIDs)
            if newValue.count == 1, let firstID = newValue.first?.id {
                expandedUnitIDs.insert(firstID)
            }
            emitValidation()
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Add Rent")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Spacer()
            Text("Tap rent to edit")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack.opacity(0.58))
            Button {
                addUnit()
            } label: {
                Label("Add Unit", systemImage: "plus")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.richBlack)
        }
    }

    private var quickActionsRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.richBlack.opacity(0.58))

            TextField("Apply rent to all", text: $applyRentToAll)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
                .keyboardType(.decimalPad)
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
            .foregroundStyle(Color.primaryYellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primaryYellow.opacity(0.14))
            )

            Button(showSquareFeet ? "Hide SqFt" : "+ SqFt") {
                showSquareFeet.toggle()
            }
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(Color.richBlack.opacity(0.72))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.softGray)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func unitRow(index: Int, unit: RentUnitInput) -> some View {
        let isExpanded = expandedUnitIDs.contains(unit.id)
        let title = unit.unitType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unit \(index + 1)" : unit.unitType

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                        .lineLimit(1)
                    Text(isExpanded ? "Details expanded" : "Tap arrow for details")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Rent")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.primaryYellow)

                        TextField("$0", text: Binding(
                            get: { units[safe: index]?.monthlyRent ?? "" },
                            set: { newValue in
                                guard units.indices.contains(index) else { return }
                                units[index].monthlyRent = InputFormatters.formatCurrencyLive(newValue)
                                emitValidation()
                            }
                        ))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($focusedRentUnitID, equals: unit.id)
                    }
                    .frame(width: 128)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.canvasWhite)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                focusedRentUnitID == unit.id
                                ? Color.primaryYellow.opacity(0.85)
                                : Color.richBlack.opacity(0.16),
                                lineWidth: focusedRentUnitID == unit.id ? 2 : 1
                            )
                    )
                }

                Button {
                    toggleExpand(id: unit.id)
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.65))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                VStack(spacing: 8) {
                    if allowsUnitType {
                        compactField(title: "Label", text: Binding(
                            get: { units[safe: index]?.unitType ?? "" },
                            set: { newValue in
                                guard units.indices.contains(index) else { return }
                                units[index].unitType = newValue
                            }
                        ), keyboard: .default)
                    }

                    HStack(spacing: 8) {
                        compactField(title: "Beds", text: Binding(
                            get: { units[safe: index]?.bedrooms ?? "" },
                            set: { newValue in
                                guard units.indices.contains(index) else { return }
                                units[index].bedrooms = InputFormatters.sanitizeDecimal(newValue)
                            }
                        ), keyboard: .numberPad)

                        compactField(title: "Baths", text: Binding(
                            get: { units[safe: index]?.bathrooms ?? "" },
                            set: { newValue in
                                guard units.indices.contains(index) else { return }
                                units[index].bathrooms = InputFormatters.sanitizeDecimal(newValue)
                            }
                        ), keyboard: .numberPad)

                        if showSquareFeet {
                            compactField(title: "SqFt", text: Binding(
                                get: { units[safe: index]?.squareFeet ?? "" },
                                set: { newValue in
                                    guard units.indices.contains(index) else { return }
                                    units[index].squareFeet = InputFormatters.sanitizeDecimal(newValue)
                                }
                            ), keyboard: .numberPad)
                        }
                    }

                    if units.count > 1 {
                        HStack {
                            Spacer()
                            Button {
                                removeUnit(id: unit.id)
                            } label: {
                                Label("Remove Unit", systemImage: "trash")
                                    .font(.system(.caption, design: .rounded).weight(.semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(rowPadding)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.softGray)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private func compactField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.56))
            TextField("", text: text)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
                .keyboardType(keyboard)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.canvasWhite)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.richBlack.opacity(0.1), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addUnit() {
        let newUnit = RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")
        units.append(newUnit)
        expandedUnitIDs.insert(newUnit.id)
        emitValidation()
    }

    private func removeUnit(id: UUID) {
        units.removeAll { $0.id == id }
        expandedUnitIDs.remove(id)
        if units.isEmpty {
            let fallback = RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")
            units = [fallback]
            expandedUnitIDs.insert(fallback.id)
        }
        emitValidation()
    }

    private func toggleExpand(id: UUID) {
        if expandedUnitIDs.contains(id) {
            expandedUnitIDs.remove(id)
        } else {
            expandedUnitIDs.insert(id)
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
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
