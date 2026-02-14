import SwiftUI
import Charts
import MapKit
import PhotosUI

struct EvaluatorView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultAppreciationRate") private var defaultAppreciationRate = 3.0
    @AppStorage("defaultMarginalTaxRate") private var defaultMarginalTaxRate = 24.0
    @AppStorage("defaultLandValuePercent") private var defaultLandValuePercent = 20.0

    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var imageURL = ""
    @State private var imagePath: String?
    @State private var purchasePrice = ""
    @State private var downPaymentPercent = ""
    @State private var interestRate = ""
    @State private var appreciationRate = ""
    @State private var marginalTaxRate = ""
    @State private var landValuePercent = ""
    @State private var appreciationUsingDefault = false
    @State private var taxRateUsingDefault = false
    @State private var landValueUsingDefault = false
    @State private var annualTaxes = ""
    @State private var annualInsurance = ""
    @State private var loanTermYears = 30
    @State private var rentRoll: [RentUnitInput] = [
        RentUnitInput(monthlyRent: "", unitType: "1BR", bedrooms: "1", bathrooms: "1")
    ]
    @State private var expenseMode: ExpenseInputMode = .simple
    @State private var simpleExpenseRate = ""
    @State private var managementFee = ""
    @State private var maintenanceReserves = ""

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showSaveToast = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    @StateObject private var searchService = LocationSearchService()
    @State private var isSearching = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isUploadingImage = false
    @State private var imageError: String?

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    propertySection
                    photoSection
                    financingSection
                    assumptionsSection
                    mortgageSection
                    operatingExpenseSection
                    rentRollSection
                    metricsSection
                    pillarsSection
                    actionSection
                }
                .padding(24)
            }

            if showSaveToast {
                VStack {
                    saveToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 8)
            }

        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadImage(image)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await uploadImage(image) }
            }
        }

        .onChange(of: showSaveToast) { _, newValue in
            if newValue {
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSaveToast = false
                    }
                }
            }
        }
        .onAppear {
            if simpleExpenseRate.isEmpty {
                simpleExpenseRate = String(standardOperatingExpenseRate)
            }

            if appreciationRate.isEmpty {
                appreciationRate = String(defaultAppreciationRate)
                appreciationUsingDefault = true
            }
            if marginalTaxRate.isEmpty {
                marginalTaxRate = String(defaultMarginalTaxRate)
                taxRateUsingDefault = true
            }
            if landValuePercent.isEmpty {
                landValuePercent = String(defaultLandValuePercent)
                landValueUsingDefault = true
            }
        }
    }
    private var propertySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Property Details")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            VStack(alignment: .leading, spacing: 8) {
                LabeledTextField(title: "Address", text: $address, keyboard: .default)
                    .onChange(of: address) { _, newValue in
                        searchService.query = newValue
                        isSearching = true
                    }

                if isSearching && !searchService.results.isEmpty {
                    addressSuggestions
                }
            }
        }
        .cardStyle()
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            // Preview if we have a URL already
            if let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            Color.softGray
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.richBlack.opacity(0.4))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 160)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let imageError {
                Text(imageError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        if isUploadingImage { ProgressView() }
                        Image(systemName: "photo.on.rectangle")
                        Text(isUploadingImage ? "Uploading..." : "Choose Photo")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isUploadingImage)

                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text("Camera")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isUploadingImage)
            }
        }
        .cardStyle()
    }

    private var financingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Financing")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            LabeledTextField(title: "Down Payment %", text: $downPaymentPercent, keyboard: .decimalPad)
                .onChange(of: downPaymentPercent) { _, newValue in
                    downPaymentPercent = InputFormatters.sanitizeDecimal(newValue)
                }
                .onSubmit {
                    if let value = Double(downPaymentPercent) {
                        downPaymentPercent = String(format: "%.2f", value)
                    }
                }
            LabeledTextField(title: "Interest Rate %", text: $interestRate, keyboard: .decimalPad)
                .onChange(of: interestRate) { _, newValue in
                    interestRate = InputFormatters.sanitizeDecimal(newValue)
                }
                .onSubmit {
                    if let value = Double(interestRate) {
                        interestRate = String(format: "%.2f", value)
                    }
                }
            LabeledTextField(title: "Annual Taxes", text: $annualTaxes, keyboard: .decimalPad)
                .onChange(of: annualTaxes) { _, newValue in
                    annualTaxes = InputFormatters.formatCurrencyLive(newValue)
                }
                .onSubmit {
                    if let value = Double(annualTaxes) {
                        annualTaxes = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? annualTaxes
                    }
                }
            LabeledTextField(title: "Annual Insurance", text: $annualInsurance, keyboard: .decimalPad)
                .onChange(of: annualInsurance) { _, newValue in
                    annualInsurance = InputFormatters.formatCurrencyLive(newValue)
                }
                .onSubmit {
                    if let value = Double(annualInsurance) {
                        annualInsurance = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? annualInsurance
                    }
                }
            Picker("Loan Term", selection: $loanTermYears) {
                Text("15 years").tag(15)
                Text("20 years").tag(20)
                Text("30 years").tag(30)
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }

    private var assumptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equity & Tax Assumptions")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            LabeledTextField(title: "Appreciation % (Annual)", text: $appreciationRate, keyboard: .decimalPad)
                .onChange(of: appreciationRate) { _, newValue in
                    appreciationRate = InputFormatters.sanitizeDecimal(newValue)
                    appreciationUsingDefault = false
                }
                .onSubmit {
                    if let value = Double(appreciationRate) {
                        appreciationRate = String(format: "%.2f", value)
                    }
                }

            LabeledTextField(title: "Marginal Tax Rate %", text: $marginalTaxRate, keyboard: .decimalPad)
                .onChange(of: marginalTaxRate) { _, newValue in
                    marginalTaxRate = InputFormatters.sanitizeDecimal(newValue)
                    taxRateUsingDefault = false
                }
                .onSubmit {
                    if let value = Double(marginalTaxRate) {
                        marginalTaxRate = String(format: "%.2f", value)
                    }
                }

            LabeledTextField(title: "Land Value %", text: $landValuePercent, keyboard: .decimalPad)
                .onChange(of: landValuePercent) { _, newValue in
                    landValuePercent = InputFormatters.sanitizeDecimal(newValue)
                    landValueUsingDefault = false
                }
                .onSubmit {
                    if let value = Double(landValuePercent) {
                        landValuePercent = String(format: "%.2f", value)
                    }
                }

            if usingDefaultsBadge {
                Text("Using defaults")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.softGray)
                    )
            }

            Text("Tax incentives use depreciation (27.5 years) based on purchase price minus land value.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.6))
        }
        .cardStyle()
    }


    private var operatingExpenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operating Expenses")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            ExpenseModuleView(
                module: expenseModule,
                annualCashFlow: computedMetrics?.annualCashFlow,
                mode: $expenseMode,
                simpleRate: $simpleExpenseRate,
                annualTaxes: $annualTaxes,
                annualInsurance: $annualInsurance,
                managementFee: $managementFee,
                maintenanceReserves: $maintenanceReserves
            )
        }
        .cardStyle()
    }

    private var mortgageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mortgage Estimator")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let breakdown = mortgageBreakdown {
                MortgageDonutChart(breakdown: breakdown)
                    .frame(height: 220)

                MetricRow(title: "Monthly P&I", value: Formatters.currency.string(from: NSNumber(value: breakdown.monthlyPrincipal + breakdown.monthlyInterest)) ?? "$0")
                MetricRow(title: "Monthly Taxes", value: Formatters.currency.string(from: NSNumber(value: breakdown.monthlyTaxes)) ?? "$0")
                MetricRow(title: "Monthly Insurance", value: Formatters.currency.string(from: NSNumber(value: breakdown.monthlyInsurance)) ?? "$0")
                MetricRow(title: "Monthly Total", value: Formatters.currency.string(from: NSNumber(value: breakdown.monthlyTotal)) ?? "$0")
            } else {
                Text("Add purchase price, rate, down payment, taxes, insurance, and loan term.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var rentRollSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rent Roll")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Button("Add Unit") {
                    rentRoll.append(RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: ""))
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
            }

            ForEach($rentRoll) { $unit in
                VStack(spacing: 10) {
                    LabeledTextField(title: "Unit Type", text: $unit.unitType, keyboard: .default)
                        .onChange(of: unit.unitType) { _, newValue in
                            let defaults = UnitTypeParser.bedsBaths(from: newValue)
                            if unit.bedrooms.trimmingCharacters(in: .whitespaces).isEmpty,
                               let beds = defaults.beds {
                                unit.bedrooms = String(beds)
                            }
                            if unit.bathrooms.trimmingCharacters(in: .whitespaces).isEmpty,
                               let baths = defaults.baths {
                                unit.bathrooms = String(baths)
                            }
                        }

                    HStack(spacing: 10) {
                        LabeledTextField(title: "Monthly Rent", text: $unit.monthlyRent, keyboard: .decimalPad)
                            .onSubmit {
                                if let value = Double(unit.monthlyRent) {
                                    unit.monthlyRent = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? unit.monthlyRent
                                }
                            }
                            .onChange(of: unit.monthlyRent) { _, newValue in
                                unit.monthlyRent = InputFormatters.formatCurrencyLive(newValue)
                            }

                        LabeledTextField(title: "Bedrooms", text: $unit.bedrooms, keyboard: .numberPad)
                            .onChange(of: unit.bedrooms) { _, newValue in
                                unit.bedrooms = InputFormatters.sanitizeDecimal(newValue)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(missingBedsOrBaths(for: unit) ? Color.red.opacity(0.8) : Color.clear, lineWidth: 1)
                            )

                        LabeledTextField(title: "Bathrooms", text: $unit.bathrooms, keyboard: .numberPad)
                            .onChange(of: unit.bathrooms) { _, newValue in
                                unit.bathrooms = InputFormatters.sanitizeDecimal(newValue)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(missingBedsOrBaths(for: unit) ? Color.red.opacity(0.8) : Color.clear, lineWidth: 1)
                            )
                    }

                    if missingBedsOrBaths(for: unit) {
                        Text("Bedrooms and bathrooms are required.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.red)
                    }
                    if rentRoll.count > 1 {
                        Button("Remove Unit") {
                            rentRoll.removeAll { $0.id == unit.id }
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.softGray)
                )

                if unit.id != rentRoll.last?.id {
                    Divider()
                        .background(Color.richBlack.opacity(0.08))
                        .padding(.vertical, 6)
                }
            }

            let totalMonthlyRent = rentRoll.compactMap { Double($0.monthlyRent) }.reduce(0, +)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Monthly Rent")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                    Text(Formatters.currency.string(from: NSNumber(value: totalMonthlyRent)) ?? "$0")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Annual Rent")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                    Text(Formatters.currency.string(from: NSNumber(value: totalMonthlyRent * 12.0)) ?? "$0")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardSurface)
            )

        }
        .cardStyle()
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Metrics")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                if let metrics = computedMetrics {
                let profile = gradeProfileStore.profiles.first(where: { $0.id == gradeProfileStore.defaultProfileId }) ?? gradeProfileStore.profiles.first ?? GradeProfile.defaultProfile
                GradeBadge(grade: evaluatorGrade ?? metrics.grade, accentColor: Color(hex: profile.colorHex))
                }
            }

            if let metrics = computedMetrics {
                let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
                LazyVGrid(columns: columns, spacing: 14) {
                    MetricTile(title: "NOI", value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0")
                    MetricTile(title: "Cap Rate", value: Formatters.percent.string(from: NSNumber(value: metrics.capRate)) ?? "0%")
                    MetricTile(title: "Cash-on-Cash", value: Formatters.percent.string(from: NSNumber(value: metrics.cashOnCash)) ?? "0%")
                    MetricTile(title: "DCR", value: String(format: "%.2f", metrics.debtCoverageRatio))
                }

                if expenseMode == .detailed, let module = expenseModule {
                    MetricRow(
                        title: "Total Operating Expenses",
                        value: Formatters.currency.string(from: NSNumber(value: module.totalOperatingExpenses)) ?? "$0"
                    )
                }
            } else {
                Text("Enter inputs to calculate metrics.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }


    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pillars")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let evaluation = pillarEvaluation {
                ForEach(evaluation.results, id: \.pillar) { result in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(result.pillar.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Spacer()
                            Text(result.status.label)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(statusColor(for: result.status))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(statusColor(for: result.status).opacity(0.12))
                                )
                        }

                        if result.pillar == .cashFlow, let monthly = result.monthlyValue, let annual = result.annualValue {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Monthly")
                                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack.opacity(0.5))
                                    Text(Formatters.currency.string(from: NSNumber(value: monthly)) ?? "$0")
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Annual")
                                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack.opacity(0.5))
                                    Text(Formatters.currency.string(from: NSNumber(value: annual)) ?? "$0")
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack)
                                }
                            }

                            if let threshold = result.thresholdValue {
                                Text("Break-even: \(Formatters.currency.string(from: NSNumber(value: threshold)) ?? "$0")/mo")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color.richBlack.opacity(0.55))
                            }
                        }

                        Text(result.detail)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("Enter inputs to evaluate the four pillars.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }


    private var actionSection: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Export Deal Summary") {
                Task { await exportPDF() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(computedMetrics == nil)

            Button(isSaving ? "Saving..." : "Save To Portfolio") {
                Task { await saveProperty() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaving)
        }
        .cardStyle()
    }

    private var computedMetrics: DealMetrics? {
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let downPaymentValue = Double(downPaymentPercent),
              let interestValue = Double(interestRate),
              let module = expenseModule else {
            return nil
        }

        let debtService = MetricsEngine.mortgageBreakdown(
            purchasePrice: purchasePriceValue,
            downPaymentPercent: downPaymentValue,
            interestRate: interestValue,
            loanTermYears: Double(loanTermYears),
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance
        ).map { $0.annualPrincipal + $0.annualInterest } ?? 0

        if expenseMode == .detailed {
            let netOperatingIncome = module.netOperatingIncome
            let annualCashFlow = netOperatingIncome - debtService
            let downPayment = max(purchasePriceValue * (downPaymentValue / 100.0), 0.0001)
            let capRate = purchasePriceValue > 0 ? netOperatingIncome / purchasePriceValue : 0
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
            purchasePrice: purchasePriceValue,
            downPaymentPercent: downPaymentValue,
            interestRate: interestValue,
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance,
            loanTermYears: Double(loanTermYears),
            rentRoll: rentRoll,
            useStandardOperatingExpense: true,
            operatingExpenseRateOverride: operatingExpenseRateValue / 100.0,
            operatingExpenses: []
        )
    }

    private var expenseModule: MFMetricEngine.ExpenseModule? {
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice) else { return nil }
        let grossAnnualRent = MFMetricEngine.grossAnnualRent(from: rentRoll)

        return MFMetricEngine.ExpenseModule(
            purchasePrice: purchasePriceValue,
            unitCount: max(rentRoll.count, 1),
            grossAnnualRent: grossAnnualRent,
            annualTaxes: InputFormatters.parseCurrency(annualTaxes),
            annualInsurance: InputFormatters.parseCurrency(annualInsurance),
            mgmtFee: InputFormatters.parseCurrency(managementFee),
            maintenanceReserves: InputFormatters.parseCurrency(maintenanceReserves)
        )
    }

    private var operatingExpenseRateValue: Double {
        Double(simpleExpenseRate) ?? standardOperatingExpenseRate
    }

    private var detailedOperatingExpenses: [OperatingExpenseItem] {
        guard let module = expenseModule else { return [] }
        return [
            OperatingExpenseItem(name: "Management Fee", annualAmount: module.effectiveManagementFee),
            OperatingExpenseItem(name: "Maintenance Reserves", annualAmount: module.effectiveMaintenanceReserves)
        ]
    }

    private var evaluatorGrade: Grade? {
        guard let metrics = computedMetrics,
              let breakdown = mortgageBreakdown,
              let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice) else { return nil }
        let profile = gradeProfileStore.profiles.first(where: { $0.id == gradeProfileStore.defaultProfileId }) ?? gradeProfileStore.profiles.first ?? GradeProfile.defaultProfile
        let appreciation = Double(appreciationRate) ?? 0
        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: purchasePriceValue,
            unitCount: max(rentRoll.count, 1),
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: appreciation,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private var pillarEvaluation: PillarEvaluation? {
        guard let metrics = computedMetrics,
              let breakdown = mortgageBreakdown,
              let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice) else {
            return nil
        }

        let appreciation = Double(appreciationRate) ?? 0
        let taxRate = Double(marginalTaxRate)
        let landPercent = Double(landValuePercent)

        return EvaluatorEngine.evaluate(
            purchasePrice: purchasePriceValue,
            annualCashFlow: metrics.annualCashFlow,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: appreciation,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            marginalTaxRate: taxRate,
            landValuePercent: landPercent
        )
    }

    private var usingDefaultsBadge: Bool {
        appreciationUsingDefault || taxRateUsingDefault || landValueUsingDefault
    }

    private func statusColor(for status: PillarStatus) -> Color {
        switch status {
        case .met:
            return Color.primaryYellow
        case .notMet:
            return Color.richBlack.opacity(0.5)
        case .needsInput:
            return Color.richBlack.opacity(0.35)
        case .borderline:
            return Color.primaryYellow.opacity(0.7)
        }
    }

    private var mortgageBreakdown: MortgageBreakdown? {
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let downPaymentValue = Double(downPaymentPercent),
              let interestValue = Double(interestRate),
              let module = expenseModule else { return nil }

        return MetricsEngine.mortgageBreakdown(
            purchasePrice: purchasePriceValue,
            downPaymentPercent: downPaymentValue,
            interestRate: interestValue,
            loanTermYears: Double(loanTermYears),
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance
        )
    }

    private func missingBedsOrBaths(for unit: RentUnitInput) -> Bool {
        let beds = unit.bedrooms.trimmingCharacters(in: .whitespaces)
        let baths = unit.bathrooms.trimmingCharacters(in: .whitespaces)
        return beds.isEmpty || baths.isEmpty || Double(beds) == nil || Double(baths) == nil
    }

    private func resetForm() {
        address = ""
        city = ""
        state = ""
        zipCode = ""
        imageURL = ""
        imagePath = nil
        purchasePrice = ""
        downPaymentPercent = ""
        interestRate = ""
        annualTaxes = ""
        annualInsurance = ""
        expenseMode = .simple
        simpleExpenseRate = String(standardOperatingExpenseRate)
        managementFee = ""
        maintenanceReserves = ""
        loanTermYears = 30
        rentRoll = [RentUnitInput(monthlyRent: "", unitType: "1BR", bedrooms: "1", bathrooms: "1")]
        isSearching = false
        searchService.results = []
    }

    private func uploadImage(_ image: UIImage) async {
        await MainActor.run { self.isUploadingImage = true; self.imageError = nil }
        do {
            let uploaded = try await ImageUploadService.uploadPropertyImage(image)
            await MainActor.run {
                self.imagePath = uploaded.path
                self.imageURL = uploaded.signedURL.absoluteString
            }
        } catch {
            await MainActor.run {
                self.imageError = error.localizedDescription
            }
        }
        await MainActor.run { self.isUploadingImage = false }
    }

    private func exportPDF() async {
        errorMessage = nil
        guard let metrics = computedMetrics,
              let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let module = expenseModule else {
            errorMessage = "Complete the inputs before exporting."
            return
        }

        let rentUnits = rentRoll.compactMap { unit -> RentUnit? in
            guard let rentValue = InputFormatters.parseCurrency(unit.monthlyRent),
                  let beds = Double(unit.bedrooms),
                  let baths = Double(unit.bathrooms),
                  beds >= 0, baths >= 0 else { return nil }
            return RentUnit(monthlyRent: rentValue, unitType: unit.unitType, bedrooms: beds, bathrooms: baths)
        }

        if rentUnits.count != rentRoll.count {
            errorMessage = "Every unit must have bedrooms and bathrooms."
            return
        }

        let property = Property(
            address: address,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            imagePath: imagePath,
            imageURL: imageURL,
            purchasePrice: purchasePriceValue,
            rentRoll: rentUnits,
            useStandardOperatingExpense: expenseMode == .simple,
            operatingExpenseRate: operatingExpenseRateValue,
            operatingExpenses: expenseMode == .detailed ? detailedOperatingExpenses : [],
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance,
            loanTermYears: loanTermYears,
            downPaymentPercent: Double(downPaymentPercent),
            interestRate: Double(interestRate),
            appreciationRate: Double(appreciationRate),
            marginalTaxRate: Double(marginalTaxRate),
            landValuePercent: Double(landValuePercent),
            gradeProfileId: gradeProfileStore.defaultProfileId
        )

        let image = await ImageLoader.loadImage(from: imageURL)

        do {
            let activeProfile = gradeProfileStore.profiles.first(where: { $0.id == gradeProfileStore.defaultProfileId }) ?? gradeProfileStore.profiles.first ?? GradeProfile.defaultProfile
            let url = try PDFService.renderDealSummary(
                property: property,
                metrics: metrics,
                image: image,
                cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
                gradeProfileName: activeProfile.name,
                gradeProfileColorHex: activeProfile.colorHex
            )
            shareURL = url
            showShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveProperty() async {
        errorMessage = nil
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let module = expenseModule else {
            errorMessage = "Enter a valid purchase price."
            return
        }

        let rentUnits = rentRoll.compactMap { unit -> RentUnit? in
            guard let rentValue = InputFormatters.parseCurrency(unit.monthlyRent),
                  let beds = Double(unit.bedrooms),
                  let baths = Double(unit.bathrooms),
                  beds >= 0, baths >= 0 else { return nil }
            return RentUnit(monthlyRent: rentValue, unitType: unit.unitType, bedrooms: beds, bathrooms: baths)
        }

        if rentUnits.count != rentRoll.count {
            errorMessage = "Every unit must have bedrooms and bathrooms."
            return
        }

        let property = Property(
            address: address,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            imagePath: imagePath,
            imageURL: imageURL,
            purchasePrice: purchasePriceValue,
            rentRoll: rentUnits,
            useStandardOperatingExpense: expenseMode == .simple,
            operatingExpenseRate: operatingExpenseRateValue,
            operatingExpenses: expenseMode == .detailed ? detailedOperatingExpenses : [],
            annualTaxes: module.effectiveAnnualTaxes,
            annualInsurance: module.effectiveAnnualInsurance,
            loanTermYears: loanTermYears,
            downPaymentPercent: Double(downPaymentPercent),
            interestRate: Double(interestRate),
            appreciationRate: Double(appreciationRate),
            marginalTaxRate: Double(marginalTaxRate),
            landValuePercent: Double(landValuePercent),
            gradeProfileId: gradeProfileStore.defaultProfileId
        )

        isSaving = true
        do {
            try await propertyStore.addProperty(property)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                showSaveToast = true
            }
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private var saveToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.primaryYellow)
            Text("Saved to portfolio")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
        )
        .padding(.horizontal, 20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evaluator")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("Stress-test every deal with confidence.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Inputs to grade in seconds.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var addressSuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchService.results, id: \.self) { item in
                Button(action: {
                    // Populate fields from the selected search result
                    address = item.title
                    // Attempt to parse city/state/zip from the subtitle if available
                    let parts = item.subtitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 2 {
                        city = parts[0]
                        // Expecting something like "CA 94103" for the second part
                        let stateZip = parts[1].split(separator: " ").map { String($0) }
                        if let st = stateZip.first {
                            state = StateAbbreviationFormatter.abbreviate(st)
                        }
                        if stateZip.count > 1, let maybeZip = stateZip.last { 
                            zipCode = maybeZip
                        }
                    }
                    isSearching = false
                    // Clear results to hide the list
                    searchService.results = []
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item != searchService.results.last {
                    Divider().background(Color.richBlack.opacity(0.08))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
}

struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }
}


#Preview {
    NavigationStack {
        EvaluatorView()
            .environmentObject(PropertyStore())
            .environmentObject(GradeProfileStore())
    }
}
