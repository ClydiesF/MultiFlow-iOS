import SwiftUI
import Charts
import MapKit

struct PropertyDetailView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @Environment(\.dismiss) private var dismiss
    let property: Property

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showEdit = false
    @State private var editOperatingExpenses = false
    @State private var useStandardOperatingExpense = true
    @State private var operatingExpenseRate = ""
    @State private var operatingExpenses: [OperatingExpenseInput] = []
    @State private var infoMetric: MetricInfoType?
    @State private var termOverride: Int?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var mapSnapshotURL: URL?
    @State private var isLoadingMap = false

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    photoSection
                    summarySection
                    locationSection
                    mortgageSection
                    metricsSection
                    pillarsSection
                    detailsSection
                    operatingExpenseSection
                    rentRollSection
                    exportSection
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEdit = true
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        .sheet(isPresented: $showEdit) {
            EditPropertySheet(property: property)
                .environmentObject(propertyStore)
                .environmentObject(gradeProfileStore)
        }
        .onAppear { loadOperatingExpenseState(); Task { await fetchMapSnapshot() } }
        .alert("Delete Property?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                dismiss()
                Task { await deleteProperty() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the property from your portfolio.")
        }
        .alert("Unable to delete", isPresented: Binding(get: {
            deleteError != nil
        }, set: { _ in
            deleteError = nil
        })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "Unknown error")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayProperty.address)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            HStack(spacing: 12) {
                GradeBadge(grade: weightedGrade, accentColor: Color(hex: activeProfile.colorHex))
                profilePill
                UnitTypeBadge(unitCount: displayProperty.rentRoll.count)
            }

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                let bedsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBeds)) ?? "\(totalBeds)"
                let bathsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBaths)) ?? "\(totalBaths)"
                Text("\(displayProperty.rentRoll.count) units • \(bedsText) Beds • \(bathsText) Baths")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }

            if let city = displayProperty.city, let state = displayProperty.state, let zip = displayProperty.zipCode,
               !city.isEmpty, !state.isEmpty, !zip.isEmpty {
                Text("\(city), \(state) \(zip)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let metrics = MetricsEngine.computeMetrics(property: displayProperty) {
                let totalOperatingExpenses = displayProperty.operatingExpenses?.reduce(0) { $0 + $1.annualAmount } ?? 0
                MetricRow(title: "Net Operating Income", value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0")
                infoMetricRow(title: "Cap Rate", value: Formatters.percent.string(from: NSNumber(value: metrics.capRate)) ?? "0%", type: .capRate)
                infoMetricRow(title: "Cash-on-Cash", value: Formatters.percent.string(from: NSNumber(value: metrics.cashOnCash)) ?? "0%", type: .cashOnCash)
                infoMetricRow(title: "DCR", value: String(format: "%.2f", metrics.debtCoverageRatio), type: .dcr)
                MetricRow(title: "Annual Cash Flow", value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow)) ?? "$0")
                cashflowChipRow(for: metrics)
                MetricRow(title: "Net Cash Flow", value: Formatters.currency.string(from: NSNumber(value: netCashFlow(for: metrics))) ?? "$0")
                if !(displayProperty.useStandardOperatingExpense ?? true) {
                    MetricRow(title: "Total Operating Expenses", value: Formatters.currency.string(from: NSNumber(value: totalOperatingExpenses)) ?? "$0")
                }
            } else {
                Text("Add financing inputs to calculate metrics.")
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
                Text("Add financing inputs to evaluate the pillars.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Details")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            MetricRow(title: "Purchase Price", value: Formatters.currency.string(from: NSNumber(value: displayProperty.purchasePrice)) ?? "$0")
            MetricRow(title: "Units", value: "\(displayProperty.rentRoll.count)")
            if let city = displayProperty.city, !city.isEmpty {
                MetricRow(title: "City", value: city)
            }
            if let state = displayProperty.state, !state.isEmpty {
                MetricRow(title: "State", value: state)
            }
            if let zip = displayProperty.zipCode, !zip.isEmpty {
                MetricRow(title: "ZIP", value: zip)
            }

            if let downPayment = displayProperty.downPaymentPercent {
                MetricRow(title: "Down Payment", value: Formatters.percentWhole.string(from: NSNumber(value: downPayment / 100)) ?? "0%")
            }

            if let interest = displayProperty.interestRate {
                MetricRow(title: "Interest Rate", value: String(format: "%.2f%%", interest))
            }

            if let taxes = displayProperty.annualTaxes {
                MetricRow(title: "Annual Taxes", value: Formatters.currency.string(from: NSNumber(value: taxes)) ?? "$0")
            }
            if let insurance = displayProperty.annualInsurance {
                MetricRow(title: "Annual Insurance", value: Formatters.currency.string(from: NSNumber(value: insurance)) ?? "$0")
            }
            if displayProperty.annualTaxes == nil,
               displayProperty.annualInsurance == nil,
               let legacy = displayProperty.annualTaxesInsurance {
                MetricRow(title: "Taxes/Insurance", value: Formatters.currency.string(from: NSNumber(value: legacy)) ?? "$0")
            }
            if let term = displayProperty.loanTermYears {
                MetricRow(title: "Loan Term", value: "\(term) years")
            }
        }
        .cardStyle()
    }

    private var mortgageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mortgage Estimator")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let breakdown = mortgageBreakdown {
                Picker("Term", selection: $termOverride) {
                    Text("15").tag(Optional(15))
                    Text("20").tag(Optional(20))
                    Text("30").tag(Optional(30))
                }
                .pickerStyle(.segmented)

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
            Text("Rent Roll")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if displayProperty.rentRoll.isEmpty {
                Text("No rent roll added yet.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            } else {
                ForEach(displayProperty.rentRoll, id: \.id) { unit in
                    VStack(spacing: 10) {
                        Text(unit.unitType.isEmpty ? "Unit" : unit.unitType)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Rent")
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack.opacity(0.5))
                                Text(Formatters.currencyTwo.string(from: NSNumber(value: unit.monthlyRent)) ?? "$0")
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bedrooms")
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack.opacity(0.5))
                                let bedsText = Formatters.bedsBaths.string(from: NSNumber(value: unit.bedrooms)) ?? "\(unit.bedrooms)"
                                Text(bedsText)
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bathrooms")
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack.opacity(0.5))
                                let bathsText = Formatters.bedsBaths.string(from: NSNumber(value: unit.bathrooms)) ?? "\(unit.bathrooms)"
                                Text(bathsText)
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.softGray)
                    )

                    if unit.id != displayProperty.rentRoll.last?.id {
                        Divider()
                            .background(Color.richBlack.opacity(0.08))
                            .padding(.vertical, 6)
                    }
                }

                let totalMonthlyRent = displayProperty.rentRoll.reduce(0) { $0 + $1.monthlyRent }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Monthly Rent")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                        Text(Formatters.currencyTwo.string(from: NSNumber(value: totalMonthlyRent)) ?? "$0")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total Annual Rent")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                        Text(Formatters.currencyTwo.string(from: NSNumber(value: totalMonthlyRent * 12.0)) ?? "$0")
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
        }
        .cardStyle()
    }


    private var operatingExpenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operating Expenses")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            Toggle("Edit operating expenses", isOn: $editOperatingExpenses)
                .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))

            if editOperatingExpenses {
                Toggle("Use standard expense rate", isOn: $useStandardOperatingExpense)
                    .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))

                if useStandardOperatingExpense {
                    LabeledTextField(title: "Standard Expense %", text: $operatingExpenseRate, keyboard: .decimalPad)
                        .onChange(of: operatingExpenseRate) { _, newValue in
                            operatingExpenseRate = InputFormatters.sanitizeDecimal(newValue)
                        }
                        .onSubmit {
                            if let value = Double(operatingExpenseRate) {
                                operatingExpenseRate = String(format: "%.2f", value)
                            }
                        }
                } else {
                    ForEach($operatingExpenses) { $expense in
                        VStack(spacing: 10) {
                            LabeledTextField(title: "Expense Name", text: $expense.name, keyboard: .default)
                            LabeledTextField(title: "Annual Amount", text: $expense.annualAmount, keyboard: .decimalPad)
                                .onChange(of: expense.annualAmount) { _, newValue in
                                    expense.annualAmount = InputFormatters.sanitizeDecimal(newValue)
                                }
                                .onSubmit {
                                    if let value = Double(expense.annualAmount) {
                                        expense.annualAmount = Formatters.currency.string(from: NSNumber(value: value)) ?? expense.annualAmount
                                    }
                                }
                            if operatingExpenses.count > 1 {
                                Button("Remove Expense") {
                                    operatingExpenses.removeAll { $0.id == expense.id }
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
                    }

                    Button("Add Expense") {
                        operatingExpenses.append(OperatingExpenseInput(name: "", annualAmount: ""))
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))

                    let total = operatingExpenses.compactMap { Double($0.annualAmount) }.reduce(0, +)
                    MetricRow(title: "Total Operating Expenses", value: Formatters.currency.string(from: NSNumber(value: total)) ?? "$0")
                }

                Button("Save Expenses") {
                    Task { await saveOperatingExpenses() }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                if displayProperty.useStandardOperatingExpense ?? true {
                    let rate = displayProperty.operatingExpenseRate ?? 35.0
                    MetricRow(title: "Standard Expense Rate", value: String(format: "%.2f%%", rate))
                } else {
                    if let expenses = displayProperty.operatingExpenses, !expenses.isEmpty {
                        ForEach(expenses, id: \.id) { item in
                            HStack {
                                Text(item.name.isEmpty ? "Expense" : item.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Spacer()
                                Text(Formatters.currency.string(from: NSNumber(value: item.annualAmount)) ?? "$0")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                            }
                            .padding(.vertical, 6)
                        }

                        let total = expenses.reduce(0) { $0 + $1.annualAmount }
                        MetricRow(title: "Total Operating Expenses", value: Formatters.currency.string(from: NSNumber(value: total)) ?? "$0")
                    } else {
                        Text("No operating expenses added.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                    }
                }
            }
        }
        .cardStyle()
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            ZStack {
                if let url = mapSnapshotURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.softGray
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 22, weight: .semibold))
                        Text(isLoadingMap ? "Loading map..." : "No map available")
                            .font(.system(.footnote, design: .rounded))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .cardStyle()
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            ZStack {
                if let url = URL(string: displayProperty.imageURL), !displayProperty.imageURL.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.softGray
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .semibold))
                        Text("No photo uploaded")
                            .font(.system(.footnote, design: .rounded))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .cardStyle()
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            let totalMonthlyRent = displayProperty.rentRoll.reduce(0) { $0 + $1.monthlyRent }
            let totalAnnualRent = totalMonthlyRent * 12

            MetricRow(title: "Annual Rent", value: Formatters.currency.string(from: NSNumber(value: totalAnnualRent)) ?? "$0")
            MetricRow(title: "Monthly Rent", value: Formatters.currency.string(from: NSNumber(value: totalMonthlyRent)) ?? "$0")

            if let metrics = MetricsEngine.computeMetrics(property: displayProperty) {
                MetricRow(title: "NOI", value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0")
                MetricRow(title: "Monthly NOI", value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome / 12)) ?? "$0")
                MetricRow(title: "Annual Cash Flow", value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow)) ?? "$0")
                performanceBadge(for: metrics)
            } else {
                Text("Add financing inputs to show NOI and cash flow.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var exportSection: some View {
        VStack(spacing: 12) {
            if let exportError {
                Text(exportError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button(isExporting ? "Preparing PDF..." : "Export Deal Summary") {
                Task { await exportPDF() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isExporting)
        }
        .cardStyle()
    }

    private func exportPDF() async {
        exportError = nil
        isExporting = true

        guard let metrics = MetricsEngine.computeMetrics(property: displayProperty) else {
            exportError = "Add financing inputs to export the report."
            isExporting = false
            return
        }

        let image = await ImageLoader.loadImage(from: displayProperty.imageURL)

        do {
            let profile = gradeProfileStore.effectiveProfile(for: displayProperty)
            let url = try PDFService.renderDealSummary(
                property: displayProperty,
                metrics: metrics,
                image: image,
                cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
                gradeProfileName: profile.name,
                gradeProfileColorHex: profile.colorHex
            )
            shareURL = url
            showShare = true
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }

    private var pillarEvaluation: PillarEvaluation? {
        guard let metrics = MetricsEngine.computeMetrics(property: displayProperty),
              let breakdown = mortgageBreakdown else {
            return nil
        }

        let appreciation = displayProperty.appreciationRate ?? 0
        return EvaluatorEngine.evaluate(
            purchasePrice: displayProperty.purchasePrice,
            annualCashFlow: metrics.annualCashFlow,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: appreciation,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            marginalTaxRate: displayProperty.marginalTaxRate,
            landValuePercent: displayProperty.landValuePercent
        )
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

    private func netCashFlow(for metrics: DealMetrics) -> Double {
        return metrics.annualCashFlow
    }

    @ViewBuilder
    private func performanceBadge(for metrics: DealMetrics) -> some View {
        let state = cashflowState(for: metrics.annualCashFlow)
        Text(state.label)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(state.color)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cashflowChipRow(for metrics: DealMetrics) -> some View {
        let state = cashflowState(for: metrics.annualCashFlow)
        return HStack {
            Text("Monthly Cash Flow")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow / 12)) ?? "$0")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            Text(state.label)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(state.color)
                )
        }
        .foregroundStyle(Color.richBlack)
        .padding(.vertical, 6)
    }

    private func cashflowState(for annualCashflow: Double) -> (label: String, color: Color) {
        if abs(annualCashflow) < cashflowBreakEvenThreshold {
            return ("Break-Even", Color.softGray)
        }
        if annualCashflow > 0 {
            return ("Positive", Color.primaryYellow.opacity(0.8))
        }
        return ("Negative", Color.red.opacity(0.2))
    }

    private func infoMetricRow(title: String, value: String, type: MetricInfoType) -> some View {
        HStack {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Button {
                    infoMetric = type
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
        }
        .foregroundStyle(Color.richBlack)
        .padding(.vertical, 6)
        .sheet(item: $infoMetric) { metric in
            MetricInfoSheet(metric: metric)
        }
    }

    private func loadOperatingExpenseState() {
        // Persisted value or default to standard behavior
        useStandardOperatingExpense = displayProperty.useStandardOperatingExpense ?? true

        // Convert optional Double rate to a string explicitly, avoid ambiguous String.init
        if let rate = displayProperty.operatingExpenseRate {
            operatingExpenseRate = String(format: "%.2f", rate)
        } else {
            operatingExpenseRate = "35"
        }

        // Map saved operating expenses to editable inputs with explicit formatting
        if let savedExpenses = displayProperty.operatingExpenses {
            operatingExpenses = savedExpenses.map { item in
                OperatingExpenseInput(
                    name: item.name,
                    annualAmount: String(format: "%.2f", item.annualAmount)
                )
            }
        } else {
            operatingExpenses = [OperatingExpenseInput(name: "Repairs", annualAmount: "")]
        }
    }

    private func saveOperatingExpenses() async {
        var updated = displayProperty
        updated.useStandardOperatingExpense = useStandardOperatingExpense
        updated.operatingExpenseRate = Double(operatingExpenseRate)
        updated.operatingExpenses = operatingExpenses.compactMap { item in
            guard let amount = InputFormatters.parseCurrency(item.annualAmount) else { return nil }
            return OperatingExpenseItem(name: item.name, annualAmount: amount)
        }

        do {
            try await propertyStore.updateProperty(updated)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteProperty() async {
        do {
            try await propertyStore.deleteProperty(displayProperty)
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func fetchMapSnapshot() async {
        if mapSnapshotURL != nil { return }
        let addressParts = [displayProperty.address, displayProperty.city, displayProperty.state, displayProperty.zipCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let fullAddress = addressParts.joined(separator: ", ")
        guard !fullAddress.isEmpty else { return }

        isLoadingMap = true
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(fullAddress)
            if let coordinate = placemarks.first?.location?.coordinate {
                let url = try await MapSnapshotService.snapshotURL(for: coordinate, title: displayProperty.address)
                mapSnapshotURL = url
            }
        } catch {
            mapSnapshotURL = nil
        }
        isLoadingMap = false
    }

    private var displayProperty: Property {
        guard let id = property.id else { return property }
        return propertyStore.properties.first { $0.id == id } ?? property
    }

    private var weightedGrade: Grade {
        guard let metrics = MetricsEngine.computeMetrics(property: displayProperty),
              let downPayment = displayProperty.downPaymentPercent,
              let interestRate = displayProperty.interestRate,
              let breakdown = MetricsEngine.mortgageBreakdown(
                purchasePrice: displayProperty.purchasePrice,
                downPaymentPercent: downPayment,
                interestRate: interestRate,
                loanTermYears: Double(displayProperty.loanTermYears ?? 30),
                annualTaxes: displayProperty.annualTaxes ?? (displayProperty.annualTaxesInsurance ?? 0),
                annualInsurance: displayProperty.annualInsurance ?? 0
              ) else {
            return MetricsEngine.computeMetrics(property: displayProperty)?.grade ?? .dOrF
        }
        let profile = gradeProfileStore.effectiveProfile(for: displayProperty)
        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: displayProperty.purchasePrice,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: displayProperty.appreciationRate ?? 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private var activeProfile: GradeProfile {
        gradeProfileStore.effectiveProfile(for: displayProperty)
    }

    private var profilePill: some View {
        Menu {
            Button("Default") { Task { await applyProfile(nil) } }
            ForEach(gradeProfileStore.profiles, id: \.id) { profile in
                Button(profile.name) { Task { await applyProfile(profile.id) } }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: activeProfile.colorHex))
                    .frame(width: 8, height: 8)
                Text(activeProfile.name)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hex: activeProfile.colorHex).opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }

    private func applyProfile(_ profileId: String?) async {
        var updated = displayProperty
        updated.gradeProfileId = profileId
        if let index = propertyStore.properties.firstIndex(where: { $0.id == updated.id }) {
            propertyStore.properties[index] = updated
        }
        do {
            try await propertyStore.updateProperty(updated)
        } catch { }
    }

    private var mortgageBreakdown: MortgageBreakdown? {
        guard let downPayment = displayProperty.downPaymentPercent,
              let interest = displayProperty.interestRate else { return nil }
        let taxes = displayProperty.annualTaxes ?? (displayProperty.annualTaxesInsurance ?? 0)
        let insurance = displayProperty.annualInsurance ?? 0
        let term = Double(termOverride ?? displayProperty.loanTermYears ?? 30)
        return MetricsEngine.mortgageBreakdown(
            purchasePrice: displayProperty.purchasePrice,
            downPaymentPercent: downPayment,
            interestRate: interest,
            loanTermYears: term,
            annualTaxes: taxes,
            annualInsurance: insurance
        )
    }

    private var totalBeds: Double {
        displayProperty.rentRoll.reduce(0) { $0 + $1.bedrooms }
    }

    private var totalBaths: Double {
        displayProperty.rentRoll.reduce(0) { $0 + $1.bathrooms }
    }
}

#Preview {
    NavigationStack {
        PropertyDetailView(
            property: Property(
                address: "410 Market Street",
                imageURL: "",
                purchasePrice: 1350000,
                    rentRoll: [
                        RentUnit(monthlyRent: 1800, unitType: "2BR/1BA", bedrooms: 2, bathrooms: 1),
                        RentUnit(monthlyRent: 1900, unitType: "2BR/1BA", bedrooms: 2, bathrooms: 1.5)
                    ],
                annualTaxes: 16000,
                annualInsurance: 8000,
                loanTermYears: 30,
                downPaymentPercent: 25,
                interestRate: 6.1
            )
        )
    }
    .environmentObject(PropertyStore())
    .environmentObject(GradeProfileStore())
}
