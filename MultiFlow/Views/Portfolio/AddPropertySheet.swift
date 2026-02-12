import SwiftUI
import UIKit

struct AddPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var didAddProperty: Bool
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0

    @StateObject private var viewModel = AnalysisWizardViewModel()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var missingFields = Set<AnalysisWizardField>()
    @State private var shakeTick = 0
    @State private var expenseMode: ExpenseInputMode = .simple
    @State private var simpleExpenseRate = ""
    @State private var annualInsuranceInput = ""
    @State private var managementFee = ""
    @State private var maintenanceReserves = ""
    @State private var rentRollInputs: [RentUnitInput] = []

    @FocusState private var focusedField: AnalysisWizardField?

    private let canvasGrey = Color.canvasWhite
    private let ink = Color.richBlack
    private let buttonBlack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.16, alpha: 1.0)
        : UIColor(red: 14.0 / 255.0, green: 14.0 / 255.0, blue: 16.0 / 255.0, alpha: 1.0)
    })
    private let propertyTypeColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                canvasGrey.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            stepOne
                                .frame(width: geo.size.width)
                            stepTwo
                                .frame(width: geo.size.width)
                            stepThree
                                .frame(width: geo.size.width)
                        }
                        .offset(x: -CGFloat(viewModel.stepIndex) * geo.size.width)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.stepIndex)
                    }

                    footer
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ink)
                }
            }
        }
        .onAppear {
            if simpleExpenseRate.isEmpty {
                simpleExpenseRate = String(standardOperatingExpenseRate)
            }
            seedRentRollInputsIfNeeded()
            focusFirstEmptyFieldForCurrentStep()
        }
        .onChange(of: viewModel.stepIndex) { _, _ in
            focusFirstEmptyFieldForCurrentStep()
        }
        .onChange(of: viewModel.purchasePrice) { _, _ in
            autoPopulateDallasTaxesIfNeeded()
        }
        .onChange(of: viewModel.city) { _, _ in
            autoPopulateDallasTaxesIfNeeded()
        }
        .onChange(of: viewModel.resolvedUnitCount) { _, _ in
            seedRentRollInputsIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Property")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == viewModel.stepIndex ? Color.primaryYellow : ink.opacity(0.15))
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var stepOne: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Step 1 · Acquisition")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(ink)

                wizardField(
                    title: "Address",
                    placeholder: "123 Main St",
                    text: $viewModel.address,
                    keyboard: .default,
                    field: .address
                )

                locationRow

                wizardField(
                    title: "Purchase Price",
                    placeholder: "$0.00",
                    text: $viewModel.purchasePrice,
                    keyboard: .decimalPad,
                    field: .purchasePrice,
                    textSize: 30
                )
                .onChange(of: viewModel.purchasePrice) { _, newValue in
                    viewModel.purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                }

                propertyIdentityPicker
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var stepTwo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Step 2 · Financing Lab")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(ink)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Down Payment")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(ink)
                        Spacer()
                        Text("\(viewModel.downPaymentPercent, specifier: "%.1f")%")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(ink)
                    }
                    Slider(value: $viewModel.downPaymentPercent, in: 10...50, step: 0.5)
                        .tint(Color.primaryYellow)

                    HStack {
                        Text("Down Payment Amount")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(ink.opacity(0.65))
                        Spacer()
                        Text(currencyString(downPaymentAmount))
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(ink)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cardSurface)
                )

                wizardField(
                    title: "Interest Rate",
                    placeholder: "6.50",
                    text: $viewModel.interestRate,
                    keyboard: .decimalPad,
                    field: .interestRate,
                    textSize: 30,
                    suffix: "%"
                )
                .onChange(of: viewModel.interestRate) { _, newValue in
                    viewModel.interestRate = InputFormatters.sanitizeDecimal(newValue)
                }

                loanTermTiles
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var locationRow: some View {
        HStack(alignment: .top, spacing: 10) {
            wizardField(
                title: "City",
                placeholder: "Dallas",
                text: $viewModel.city,
                keyboard: .default,
                field: .city
            )
            .frame(maxWidth: .infinity)

            wizardField(
                title: "State",
                placeholder: "TX",
                text: $viewModel.state,
                keyboard: .default,
                field: .state
            )
            .frame(width: 86)
            .onChange(of: viewModel.state) { _, newValue in
                viewModel.state = String(newValue.prefix(2)).uppercased()
            }

            wizardField(
                title: "ZIP",
                placeholder: "75001",
                text: $viewModel.zipCode,
                keyboard: .numberPad,
                field: .zip
            )
            .frame(width: 118)
            .onChange(of: viewModel.zipCode) { _, newValue in
                viewModel.zipCode = newValue.filter(\.isNumber)
            }
        }
    }

    private var stepThree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Step 3 · Operations")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(ink)

                wizardField(
                    title: "Reno Budget (Optional)",
                    placeholder: "$0.00",
                    text: $viewModel.renoBudget,
                    keyboard: .decimalPad,
                    field: .renoBudget,
                    textSize: 30
                )
                .onChange(of: viewModel.renoBudget) { _, newValue in
                    viewModel.renoBudget = InputFormatters.formatCurrencyLive(newValue)
                }

                ExpenseModuleView(
                    module: wizardExpenseModule,
                    annualCashFlow: wizardMetrics?.annualCashFlow,
                    mode: $expenseMode,
                    simpleRate: $simpleExpenseRate,
                    annualTaxes: $viewModel.annualTaxes,
                    annualInsurance: $annualInsuranceInput,
                    managementFee: $managementFee,
                    maintenanceReserves: $maintenanceReserves
                )

                RentRollEditorView(
                    units: $rentRollInputs,
                    style: .compact,
                    allowsUnitType: true,
                    requiresValidRentRow: false
                )

                if viewModel.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "dallas" {
                    Text("Dallas detected: taxes auto-populate at 2.23% of purchase price.")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(ink.opacity(0.62))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GradeCircleView(grade: liveGrade)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Grade")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(ink.opacity(0.72))
                    Text(gradeSubtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                if viewModel.stepIndex > 0 {
                    Button {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.stepIndex -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(ink.opacity(0.24), lineWidth: 1)
                            )
                    }
                    .disabled(isSaving)
                }

                ZStack {
                    Button {
                        focusedField = nil
                        if viewModel.stepIndex < 2 {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.stepIndex += 1
                            }
                        } else {
                            Task { await saveProperty() }
                        }
                    } label: {
                        Text(viewModel.stepIndex == 2 ? (isSaving ? "Saving..." : "Save Property") : "Next")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(viewModel.canProceedToNextStep ? Color.richBlack : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.canProceedToNextStep ? Color.primaryYellow : buttonBlack)
                        )
                }
                    .opacity(viewModel.canProceedToNextStep ? 1 : 0.4)
                    .disabled(!viewModel.canProceedToNextStep || isSaving)

                    if !viewModel.canProceedToNextStep && !isSaving {
                        Button {
                            handleInvalidNextTap()
                        } label: {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.clear)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Text("Fast estimate. Finish details in Property Detail.")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(ink.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(height: 150)
        .background(
            Rectangle()
                .fill(canvasGrey)
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: -6)
        )
    }

    private var propertyIdentityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Property Identity")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(ink.opacity(0.74))

            LazyVGrid(columns: propertyTypeColumns, spacing: 12) {
                ForEach(PropertyType.allCases) { type in
                    Button {
                        selectPropertyType(type)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: type.symbol)
                                .font(.system(size: 20, weight: .semibold))
                            Text(type.label)
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)
                        }
                        .foregroundStyle(viewModel.propertyType == type ? Color.primaryYellow : ink)
                        .frame(maxWidth: .infinity, minHeight: 86)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.propertyType == type ? buttonBlack : Color.cardSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    viewModel.propertyType == type
                                    ? Color.primaryYellow.opacity(0.55)
                                    : Color.black.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .scaleEffect(viewModel.propertyType == type ? 1.0 : 0.985)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: viewModel.propertyType)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(missingFields.contains(.propertyType) ? Color.red.opacity(0.85) : .clear, lineWidth: 2)
            )
            .modifier(ShakeEffect(shakes: missingFields.contains(.propertyType) ? CGFloat(shakeTick) : 0))

            if viewModel.propertyType == .tenPlus {
                wizardField(
                    title: "Exact Unit Count",
                    placeholder: "10",
                    text: $viewModel.exactUnitsForTenPlus,
                    keyboard: .numberPad,
                    field: .exactUnitsForTenPlus,
                    textSize: 26
                )
                .onChange(of: viewModel.exactUnitsForTenPlus) { _, newValue in
                    viewModel.exactUnitsForTenPlus = newValue.filter(\.isNumber)
                }
            }
        }
    }

    private var loanTermTiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Loan Term")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(ink.opacity(0.74))

            HStack(spacing: 12) {
                loanTermTile(years: 15)
                loanTermTile(years: 30)
            }
        }
    }

    private func loanTermTile(years: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                viewModel.loanTermYears = years
            }
        } label: {
            Text("\(years) Years")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(viewModel.loanTermYears == years ? Color.primaryYellow : ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(viewModel.loanTermYears == years ? buttonBlack : Color.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            viewModel.loanTermYears == years
                            ? Color.primaryYellow.opacity(0.55)
                            : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func wizardField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        field: AnalysisWizardField,
        textSize: CGFloat = 18,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(ink.opacity(0.74))

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholder)
                        .foregroundStyle(Color(red: 96.0 / 255.0, green: 96.0 / 255.0, blue: 102.0 / 255.0))
                )
                    .keyboardType(keyboard)
                    .font(.system(size: textSize, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .focused($focusedField, equals: field)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let suffix {
                    Text(suffix)
                        .font(.system(size: textSize * 0.8, weight: .bold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.72))
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        borderColor(for: field),
                        lineWidth: focusedField == field || missingFields.contains(field) ? 2 : 0
                    )
            )
        }
        .modifier(ShakeEffect(shakes: missingFields.contains(field) ? CGFloat(shakeTick) : 0))
    }

    private func borderColor(for field: AnalysisWizardField) -> Color {
        if missingFields.contains(field) {
            return Color.red.opacity(0.85)
        }
        if focusedField == field {
            return Color.primaryYellow
        }
        return .clear
    }

    private var liveGrade: Grade {
        guard let metrics = wizardMetrics,
              let purchase = effectivePurchasePrice,
              let breakdown = wizardMortgageBreakdown else {
            return wizardMetrics?.grade ?? .dOrF
        }

        let profile = gradeProfileStore.profiles.first(where: { $0.id == gradeProfileStore.defaultProfileId })
            ?? gradeProfileStore.profiles.first
            ?? GradeProfile.defaultProfile

        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: purchase,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private var wizardMetrics: DealMetrics? {
        guard let effectivePurchase = effectivePurchasePrice, effectivePurchase > 0 else { return nil }
        guard let interest = Double(viewModel.interestRate), interest > 0 else { return nil }
        guard let module = wizardExpenseModule else { return nil }

        let roll = (0..<module.unitCount).map { _ in
            RentUnitInput(monthlyRent: String(defaultMonthlyRentPerUnit), unitType: "Unit", bedrooms: "", bathrooms: "")
        }
        let editorRoll = rentRollInputs
        let hasRentRoll = RentRollEditorView.hasAtLeastOneValidRentRow(editorRoll)
        let rollForMetrics = hasRentRoll ? editorRoll : roll

        let debtService = MetricsEngine.mortgageBreakdown(
            purchasePrice: effectivePurchase,
            downPaymentPercent: viewModel.downPaymentPercent,
            interestRate: interest,
            loanTermYears: Double(viewModel.loanTermYears),
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance
        ).map { $0.annualPrincipal + $0.annualInterest } ?? 0

        if expenseMode == .detailed {
            let netOperatingIncome = module.netOperatingIncome
            let annualCashFlow = netOperatingIncome - debtService
            let downPayment = max(effectivePurchase * (viewModel.downPaymentPercent / 100.0), 0.0001)
            let capRate = effectivePurchase > 0 ? netOperatingIncome / effectivePurchase : 0
            let cashOnCash = annualCashFlow / downPayment
            let dcr = debtService > 0 ? netOperatingIncome / debtService : 0

            return DealMetrics(
                totalAnnualRent: module.grossAnnualRent,
                netOperatingIncome: netOperatingIncome,
                capRate: capRate,
                annualDebtService: debtService,
                annualCashFlow: annualCashFlow,
                cashOnCash: cashOnCash,
                debtCoverageRatio: dcr,
                grade: MetricsEngine.gradeFor(cashOnCash: cashOnCash, dcr: dcr)
            )
        }

        return MetricsEngine.computeMetrics(
            purchasePrice: effectivePurchase,
            downPaymentPercent: viewModel.downPaymentPercent,
            interestRate: interest,
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance,
            loanTermYears: Double(viewModel.loanTermYears),
            rentRoll: rollForMetrics,
            useStandardOperatingExpense: true,
            operatingExpenseRateOverride: operatingExpenseRateValue / 100.0,
            operatingExpenses: []
        )
    }

    private var wizardMortgageBreakdown: MortgageBreakdown? {
        guard let effectivePurchase = effectivePurchasePrice, effectivePurchase > 0 else { return nil }
        guard let interest = Double(viewModel.interestRate), interest > 0 else { return nil }
        guard let module = wizardExpenseModule else { return nil }
        return MetricsEngine.mortgageBreakdown(
            purchasePrice: effectivePurchase,
            downPaymentPercent: viewModel.downPaymentPercent,
            interestRate: interest,
            loanTermYears: Double(viewModel.loanTermYears),
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance
        )
    }

    private var gradeSubtitle: String {
        guard let metrics = wizardMetrics else { return "Enter deal inputs to grade." }
        let monthly = metrics.annualCashFlow / 12.0
        let cashFlow = Formatters.currency.string(from: NSNumber(value: monthly)) ?? "$0"
        return "Cash Flow \(cashFlow)/mo"
    }

    private func handleInvalidNextTap() {
        missingFields = viewModel.missingFieldsForCurrentStep()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        withAnimation(.easeInOut(duration: 0.22)) {
            shakeTick += 1
        }
        focusFirstEmptyFieldForCurrentStep()
    }

    private func focusFirstEmptyFieldForCurrentStep() {
        let nextField = viewModel.firstEmptyFieldForCurrentStep()
        focusedField = (nextField == .propertyType) ? nil : nextField
    }

    @MainActor
    private func saveProperty() async {
        errorMessage = nil

        guard let purchase = parseCurrency(viewModel.purchasePrice), purchase > 0 else {
            errorMessage = "Enter a valid purchase price."
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.stepIndex = 0
            }
            return
        }
        guard let unitCount = viewModel.resolvedUnitCount, unitCount > 0 else {
            errorMessage = "Enter valid unit count."
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.stepIndex = 0
            }
            return
        }
        guard let interest = Double(viewModel.interestRate), interest > 0 else {
            errorMessage = "Enter a valid interest rate."
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.stepIndex = 1
            }
            return
        }
        guard let module = wizardExpenseModule else {
            errorMessage = "Complete the inputs to save."
            return
        }

        let enteredRentUnits = RentRollEditorView.validUnits(from: rentRollInputs)
        let rentRoll: [RentUnit]
        if enteredRentUnits.isEmpty {
            rentRoll = [
                RentUnit(
                    monthlyRent: 0,
                    unitType: "Unit 1",
                    bedrooms: 0,
                    bathrooms: 0
                )
            ]
        } else {
            rentRoll = enteredRentUnits
        }

        let missingAnalysisInputs = buildMissingAnalysisInputs(
            hasRentRoll: !enteredRentUnits.isEmpty,
            hasCapex: false,
            hasReviewedExpenses: expenseMode == .detailed
        )

        let property = Property(
            address: viewModel.address.isEmpty ? "Untitled Property" : viewModel.address,
            city: viewModel.city.isEmpty ? nil : viewModel.city,
            state: viewModel.state.isEmpty ? nil : viewModel.state,
            zipCode: viewModel.zipCode.isEmpty ? nil : viewModel.zipCode,
            imageURL: "",
            purchasePrice: purchase,
            rentRoll: rentRoll,
            useStandardOperatingExpense: expenseMode == .simple,
            operatingExpenseRate: operatingExpenseRateValue,
            operatingExpenses: expenseMode == .detailed ? detailedOperatingExpenses : [],
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance,
            loanTermYears: viewModel.loanTermYears,
            downPaymentPercent: viewModel.downPaymentPercent,
            interestRate: interest,
            gradeProfileId: safeDefaultGradeProfileId,
            analysisCompleteness: Property.AnalysisCompletenessState.provisional.rawValue,
            missingAnalysisInputs: missingAnalysisInputs,
            renoBudget: parseCurrency(viewModel.renoBudget)
        )

        isSaving = true
        defer { isSaving = false }

        do {
            try await propertyStore.addProperty(property)
            didAddProperty = true
            dismiss()
        } catch {
            errorMessage = friendlySaveError(from: error)
        }
    }

    private func autoPopulateDallasTaxesIfNeeded() {
        let location = viewModel.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard location == "dallas" else { return }
        guard let purchase = parseCurrency(viewModel.purchasePrice), purchase > 0 else { return }
        let autoTax = purchase * 0.0223
        viewModel.annualTaxes = Formatters.currencyTwo.string(from: NSNumber(value: autoTax)) ?? viewModel.annualTaxes
    }

    private func parseCurrency(_ value: String) -> Double? {
        InputFormatters.parseCurrency(value)
    }

    private var effectivePurchasePrice: Double? {
        guard let purchase = parseCurrency(viewModel.purchasePrice), purchase > 0 else { return nil }
        return purchase + (parseCurrency(viewModel.renoBudget) ?? 0)
    }

    private var safeDefaultGradeProfileId: String? {
        guard let id = gradeProfileStore.defaultProfileId, UUID(uuidString: id) != nil else {
            return nil
        }
        return id
    }

    private var wizardExpenseModule: MFMetricEngine.ExpenseModule? {
        guard let purchase = parseCurrency(viewModel.purchasePrice), purchase > 0 else { return nil }
        guard let unitCount = viewModel.resolvedUnitCount, unitCount > 0 else { return nil }
        let enteredRentUnits = RentRollEditorView.validUnits(from: rentRollInputs)
        let grossAnnualRent: Double
        let moduleUnitCount: Int
        if enteredRentUnits.isEmpty {
            grossAnnualRent = Double(unitCount) * defaultMonthlyRentPerUnit * 12.0
            moduleUnitCount = unitCount
        } else {
            grossAnnualRent = enteredRentUnits.reduce(0) { $0 + $1.monthlyRent } * 12.0
            moduleUnitCount = enteredRentUnits.count
        }
        return MFMetricEngine.ExpenseModule(
            purchasePrice: purchase,
            unitCount: moduleUnitCount,
            grossAnnualRent: grossAnnualRent,
            annualTaxes: parseCurrency(viewModel.annualTaxes),
            annualInsurance: parseCurrency(annualInsuranceInput),
            mgmtFee: parseCurrency(managementFee),
            maintenanceReserves: parseCurrency(maintenanceReserves)
        )
    }

    private var operatingExpenseRateValue: Double {
        Double(simpleExpenseRate) ?? standardOperatingExpenseRate
    }

    private var detailedOperatingExpenses: [OperatingExpenseItem] {
        guard let module = wizardExpenseModule else { return [] }
        return [
            OperatingExpenseItem(name: "Management Fee", annualAmount: module.effectiveManagementFee),
            OperatingExpenseItem(name: "Maintenance Reserves", annualAmount: module.effectiveMaintenanceReserves)
        ]
    }

    private func friendlySaveError(from error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("not authenticated") {
            return "Please sign in again, then save the property."
        }
        if message.localizedCaseInsensitiveContains("invalid input syntax for type uuid") {
            return "A profile reference is invalid. Open Grade Profiles once, then try saving again."
        }
        if message.localizedCaseInsensitiveContains("column") || message.localizedCaseInsensitiveContains("relation") {
            return "Supabase schema looks incomplete. Apply the SQL files in /Users/clydiesfreeman/MultiFlow/supabase/migrations, then retry."
        }
        return message
    }

    private var downPaymentAmount: Double {
        guard let purchase = parseCurrency(viewModel.purchasePrice) else { return 0 }
        return purchase * (viewModel.downPaymentPercent / 100.0)
    }

    private func buildMissingAnalysisInputs(
        hasRentRoll: Bool,
        hasCapex: Bool,
        hasReviewedExpenses: Bool
    ) -> [String] {
        var missing: [String] = []
        if !hasRentRoll { missing.append("rent_roll") }
        if !hasCapex { missing.append("capex_reno") }
        if !hasReviewedExpenses { missing.append("review_expenses") }
        return missing
    }

    private func currencyString(_ value: Double) -> String {
        Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func selectPropertyType(_ type: PropertyType) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
            viewModel.propertyType = type
        }

        if type.isCommercial {
            let thud = UIImpactFeedbackGenerator(style: .heavy)
            thud.prepare()
            thud.impactOccurred(intensity: 0.95)
        } else {
            let tap = UIImpactFeedbackGenerator(style: .light)
            tap.prepare()
            tap.impactOccurred(intensity: 0.8)
        }

        if type != .tenPlus {
            viewModel.exactUnitsForTenPlus = ""
        } else if viewModel.exactUnitsForTenPlus.isEmpty {
            viewModel.exactUnitsForTenPlus = "10"
        }

        seedRentRollInputsIfNeeded()
    }

    private func seedRentRollInputsIfNeeded() {
        guard rentRollInputs.isEmpty else { return }
        rentRollInputs = [
            RentUnitInput(
                monthlyRent: "",
                unitType: "Unit 1",
                bedrooms: "",
                bathrooms: "",
                squareFeet: ""
            )
        ]
    }
}

private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 7 * sin(shakes * .pi * 2.5)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    AddPropertySheetPreviewHost()
}

private struct AddPropertySheetPreviewHost: View {
    @State private var didAddProperty = false
    @StateObject private var propertyStore = PropertyStore(repository: PreviewPropertyRepository())
    @StateObject private var gradeProfileStore = GradeProfileStore(repository: PreviewGradeProfileRepository())

    var body: some View {
        AddPropertySheet(didAddProperty: $didAddProperty)
            .environmentObject(propertyStore)
            .environmentObject(gradeProfileStore)
    }
}

private final class PreviewPropertyRepository: PropertyRepositoryProtocol {
    func fetchProperties(for userId: String) async throws -> [Property] { [] }
    func addProperty(_ property: Property, userId: String) async throws {}
    func updateProperty(_ property: Property, userId: String) async throws {}
    func deleteProperty(id: String, userId: String) async throws {}
    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws {}
    func stopListening() async {}
}

private final class PreviewGradeProfileRepository: GradeProfileRepositoryProtocol {
    func fetchProfiles(for userId: String) async throws -> [GradeProfile] { [GradeProfile.defaultProfile] }
    func fetchDefaultProfileId(for userId: String) async throws -> String? { nil }
    func addProfile(_ profile: GradeProfile, userId: String) async throws -> String { profile.id ?? UUID().uuidString }
    func updateProfile(_ profile: GradeProfile, userId: String) async throws {}
    func deleteProfile(id: String, userId: String) async throws {}
    func setDefaultProfileId(_ profileId: String?, userId: String) async throws {}
    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws {}
    func stopListening() async {}
}
