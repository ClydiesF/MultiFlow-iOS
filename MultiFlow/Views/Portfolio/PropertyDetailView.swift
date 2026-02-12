import SwiftUI
import Charts
import MapKit
import UIKit

struct PropertyDetailView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0
    @Environment(\.dismiss) private var dismiss
    let property: Property

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var isEditingAnalysis = false
    @State private var showDiscardChangesConfirm = false
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var purchasePrice = ""
    @State private var downPaymentPercent = ""
    @State private var interestRate = ""
    @State private var annualTaxes = ""
    @State private var annualInsurance = ""
    @State private var loanTermYears = 30
    @State private var rentRollInputs: [RentUnitInput] = []
    @State private var expenseMode: ExpenseInputMode = .simple
    @State private var simpleExpenseRate = ""
    @State private var managementFee = ""
    @State private var maintenanceReserves = ""
    @State private var selectedProfileId: String?
    @State private var renoBudget = ""
    @State private var capexInputs: [CapexItemInput] = []
    @State private var applyRentToAll = ""
    @State private var isSavingAnalysis = false
    @State private var infoMetric: MetricInfoType?
    @State private var termOverride: Int?
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var mapSnapshotURL: URL?
    @State private var mapCoordinate: CLLocationCoordinate2D?
    @State private var isLoadingMap = false
    @State private var inlineRentRollInputs: [RentUnitInput] = []
    @State private var inlineRentRollIsValid = false
    @State private var inlineRentRollIsSaving = false
    @State private var inlineRentRollError: String?
    @State private var inlineRentRollAutosaveTask: Task<Void, Never>?
    @State private var inlineRentRollLastSavedFingerprint = ""

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    completeAnalysisSection
                    photoSection
                    summarySection
                    if isEditingAnalysis {
                        analysisEditSection
                    }
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
                Button(isEditingAnalysis ? "Cancel" : "Edit Analysis") {
                    if isEditingAnalysis {
                        showDiscardChangesConfirm = true
                    } else {
                        beginAnalysisEdit()
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        .onAppear {
            simpleExpenseRate = String(standardOperatingExpenseRate)
            syncInlineRentRollInputs(from: activeProperty)
            Task { await fetchMapSnapshot() }
        }
        .onChange(of: activeProperty.id) { _, _ in
            if !isEditingAnalysis {
                mapSnapshotURL = nil
                Task { await fetchMapSnapshot() }
            }
            if !isEditingAnalysis {
                syncInlineRentRollInputs(from: activeProperty)
            }
        }
        .onChange(of: activeProperty.rentRoll) { _, _ in
            guard !isEditingAnalysis else { return }
            syncInlineRentRollInputs(from: activeProperty)
        }
        .onChange(of: inlineRentRollInputs) { _, _ in
            scheduleInlineRentRollAutosave()
        }
        .onDisappear {
            inlineRentRollAutosaveTask?.cancel()
        }
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
        .confirmationDialog("Discard unsaved analysis changes?", isPresented: $showDiscardChangesConfirm, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) {
                isEditingAnalysis = false
                exportError = nil
            }
            Button("Keep Editing", role: .cancel) { }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activeProperty.address)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            HStack(spacing: 12) {
                GradeBadge(grade: weightedGrade, accentColor: Color(hex: activeProfile.colorHex))
                profilePill
                UnitTypeBadge(unitCount: activeProperty.rentRoll.count)
                if activeProperty.isProvisionalEstimate {
                    Text("Estimate")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryYellow.opacity(0.9))
                        )
                }
            }

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                let bedsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBeds)) ?? "\(totalBeds)"
                let bathsText = Formatters.bedsBaths.string(from: NSNumber(value: totalBaths)) ?? "\(totalBaths)"
                Text("\(activeProperty.rentRoll.count) units • \(bedsText) Beds • \(bathsText) Baths")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }

            if let city = activeProperty.city, let state = activeProperty.state, let zip = activeProperty.zipCode,
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

            if let metrics = analysisMetrics {
                let totalOperatingExpenses = expenseModule?.totalOperatingExpenses ?? (activeProperty.operatingExpenses?.reduce(0) { $0 + $1.annualAmount } ?? 0)
                let capexAdjustedCashFlow = metrics.annualCashFlow - annualizedCapex(for: activeProperty)
                MetricRow(title: "Net Operating Income", value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0")
                infoMetricRow(title: "Cap Rate", value: Formatters.percent.string(from: NSNumber(value: metrics.capRate)) ?? "0%", type: .capRate)
                infoMetricRow(title: "Cash-on-Cash", value: Formatters.percent.string(from: NSNumber(value: metrics.cashOnCash)) ?? "0%", type: .cashOnCash)
                infoMetricRow(title: "DCR", value: String(format: "%.2f", metrics.debtCoverageRatio), type: .dcr)
                MetricRow(title: "Annual Cash Flow", value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow)) ?? "$0")
                if annualizedCapex(for: activeProperty) > 0 {
                    MetricRow(title: "Stress-Test Cash Flow (After Capex/Reno)", value: Formatters.currency.string(from: NSNumber(value: capexAdjustedCashFlow)) ?? "$0")
                }
                cashflowChipRow(for: metrics)
                MetricRow(title: "Net Cash Flow", value: Formatters.currency.string(from: NSNumber(value: netCashFlow(for: metrics))) ?? "$0")
                if !(activeProperty.useStandardOperatingExpense ?? true) {
                    MetricRow(title: "Total Operating Expenses", value: Formatters.currency.string(from: NSNumber(value: totalOperatingExpenses)) ?? "$0")
                }
                if usesFallbackRent(for: activeProperty) {
                    Text("Estimated using default rent (\(Formatters.currency.string(from: NSNumber(value: defaultMonthlyRentPerUnit)) ?? "$0") per unit).")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
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

            MetricRow(title: "Purchase Price", value: Formatters.currency.string(from: NSNumber(value: activeProperty.purchasePrice)) ?? "$0")
            MetricRow(title: "Units", value: "\(activeProperty.rentRoll.count)")
            if let city = activeProperty.city, !city.isEmpty {
                MetricRow(title: "City", value: city)
            }
            if let state = activeProperty.state, !state.isEmpty {
                MetricRow(title: "State", value: state)
            }
            if let zip = activeProperty.zipCode, !zip.isEmpty {
                MetricRow(title: "ZIP", value: zip)
            }

            if let downPayment = activeProperty.downPaymentPercent {
                MetricRow(title: "Down Payment", value: Formatters.percentWhole.string(from: NSNumber(value: downPayment / 100)) ?? "0%")
            }

            if let interest = activeProperty.interestRate {
                MetricRow(title: "Interest Rate", value: String(format: "%.2f%%", interest))
            }

            if let taxes = activeProperty.annualTaxes {
                MetricRow(title: "Annual Taxes", value: Formatters.currency.string(from: NSNumber(value: taxes)) ?? "$0")
            }
            if let insurance = activeProperty.annualInsurance {
                MetricRow(title: "Annual Insurance", value: Formatters.currency.string(from: NSNumber(value: insurance)) ?? "$0")
            }
            if activeProperty.annualTaxes == nil,
               activeProperty.annualInsurance == nil,
               let legacy = activeProperty.annualTaxesInsurance {
                MetricRow(title: "Taxes/Insurance", value: Formatters.currency.string(from: NSNumber(value: legacy)) ?? "$0")
            }
            if let term = activeProperty.loanTermYears {
                MetricRow(title: "Loan Term", value: "\(term) years")
            }
            if let reno = activeProperty.renoBudget, reno > 0 {
                MetricRow(title: "Reno Budget", value: Formatters.currency.string(from: NSNumber(value: reno)) ?? "$0")
            }
            let capexTotal = (activeProperty.capexItems ?? []).reduce(0) { $0 + $1.annualAmount }
            if capexTotal > 0 {
                MetricRow(title: "Annual Capex", value: Formatters.currency.string(from: NSNumber(value: capexTotal)) ?? "$0")
            }
            if let completeness = activeProperty.analysisCompleteness {
                MetricRow(title: "Analysis Status", value: completeness.replacingOccurrences(of: "_", with: " ").capitalized)
            }
        }
        .cardStyle()
    }
    private var mortgageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mortgage Estimator")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Payment mix and monthly impact")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
                Spacer()
                if let breakdown = mortgageBreakdown {
                    Text("$\(Formatters.currency.string(from: NSNumber(value: breakdown.monthlyTotal)) ?? "$0")")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                }
            }

            if let breakdown = mortgageBreakdown {
                VStack(spacing: 12) {
                    Picker("Term", selection: $termOverride) {
                        Text("15").tag(Optional(15))
                        Text("20").tag(Optional(20))
                        Text("30").tag(Optional(30))
                    }
                    .pickerStyle(.segmented)

                    MortgageDonutChart(breakdown: breakdown)
                        .frame(height: 210)

                    VStack(spacing: 10) {
                        mortgageLine(title: "Principal & Interest", value: breakdown.monthlyPrincipal + breakdown.monthlyInterest, tint: Color.primaryYellow)
                        mortgageLine(title: "Taxes", value: breakdown.monthlyTaxes, tint: Color.softGray)
                        mortgageLine(title: "Insurance", value: breakdown.monthlyInsurance, tint: Color.softGray.opacity(0.7))
                    }

                    HStack {
                        Text("Monthly Total")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                        Spacer()
                        Text(Formatters.currency.string(from: NSNumber(value: breakdown.monthlyTotal)) ?? "$0")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                    }
                    .padding(.top, 6)
                }
            } else {
                Text("Add purchase price, rate, down payment, taxes, insurance, and loan term.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private func mortgageLine(title: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint)
                .frame(width: 28, height: 8)
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            Spacer()
            Text(Formatters.currency.string(from: NSNumber(value: value)) ?? "$0")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
    }

    private var rentRollSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rent Roll")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Inline editing is live. Save when ready.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                }
                Spacer()
                if isEditingAnalysis {
                    Text("Finish analysis edit to save here")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                        .multilineTextAlignment(.trailing)
                }
            }

            RentRollEditorView(
                units: $inlineRentRollInputs,
                style: .full,
                allowsUnitType: true,
                requiresValidRentRow: true
            ) { valid in
                inlineRentRollIsValid = valid
            }

            HStack {
                if inlineRentRollIsSaving {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Saving rent roll...")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.68))
                } else if let inlineRentRollError {
                    Text(inlineRentRollError)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                } else if inlineRentRollIsValid {
                    Text("Auto-save enabled")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.65))
                } else {
                    Text("Enter rent for at least one unit")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                }
                Spacer()
            }
        }
        .cardStyle()
    }


    private var operatingExpenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operating Expenses")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if activeProperty.useStandardOperatingExpense ?? true {
                let rate = activeProperty.operatingExpenseRate ?? standardOperatingExpenseRate
                MetricRow(title: "Standard Expense Rate", value: String(format: "%.2f%%", rate))
            } else if let expenses = activeProperty.operatingExpenses, !expenses.isEmpty {
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
            } else if let module = expenseModule {
                MetricRow(title: "Total Operating Expenses", value: Formatters.currency.string(from: NSNumber(value: module.totalOperatingExpenses)) ?? "$0")
            } else {
                Text("No operating expense inputs available.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }
    private var locationSection: some View {
        Button {
            openInMaps()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Location")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                        Text("Open Map")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.softGray)
                    )
                }

                ZStack(alignment: .bottomLeading) {
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
                        Color.softGray
                        VStack(spacing: 6) {
                            Image(systemName: "map")
                                .font(.system(size: 22, weight: .semibold))
                            Text(isLoadingMap ? "Locating..." : "No map preview")
                                .font(.system(.footnote, design: .rounded))
                        }
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activeProperty.address)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        if let city = activeProperty.city, let state = activeProperty.state, let zip = activeProperty.zipCode,
                           !city.isEmpty, !state.isEmpty, !zip.isEmpty {
                            Text("\(city), \(state) \(zip)")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cardSurface.opacity(0.95))
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                    )
                    .padding(12)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(mapCoordinate == nil ? "Tap to locate in Maps" : "Open in Apple Maps")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            ZStack {
                if let url = URL(string: activeProperty.imageURL), !activeProperty.imageURL.isEmpty {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Core performance snapshot")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
                Spacer()
                if let metrics = analysisMetrics {
                    let state = cashflowState(for: metrics.annualCashFlow)
                    Text(state.label)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(state.color)
                        )
                }
            }

            if let metrics = analysisMetrics {
                let annualCash = metrics.annualCashFlow
                let monthlyCash = annualCash / 12
                let noi = metrics.netOperatingIncome
                let capRate = metrics.capRate

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        summaryTile(title: "Net Operating Income", value: Formatters.currency.string(from: NSNumber(value: noi)) ?? "$0")
                        summaryTile(title: "Monthly Cash Flow", value: Formatters.currency.string(from: NSNumber(value: monthlyCash)) ?? "$0")
                    }
                    HStack(spacing: 12) {
                        summaryTile(title: "Annual Cash Flow", value: Formatters.currency.string(from: NSNumber(value: annualCash)) ?? "$0")
                        summaryTile(title: "Cap Rate", value: Formatters.percent.string(from: NSNumber(value: capRate)) ?? "0%")
                    }
                }
            } else {
                Text("Add financing inputs to show NOI, cash flow, and cap rate.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private func summaryTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primaryYellow.opacity(0.75), lineWidth: 1)
        )
    }

    private var completeAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Complete Analysis")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text(activeProperty.isProvisionalEstimate ? "Fast-add estimate detected. Finish key inputs for full underwriting." : "Analysis inputs are in a strong state.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                }
                Spacer()
                Image(systemName: activeProperty.isProvisionalEstimate ? "clock.badge.exclamationmark" : "checkmark.seal.fill")
                    .foregroundStyle(activeProperty.isProvisionalEstimate ? Color.primaryYellow : Color.richBlack.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 8) {
                checklistRow("Add rent roll", complete: hasCompletedRentRoll(for: activeProperty))
                checklistRow("Add capex/reno", complete: hasCapexData(for: activeProperty))
                checklistRow("Review expenses", complete: hasReviewedExpenses(for: activeProperty))
            }

            Button(isEditingAnalysis ? "Editing Analysis..." : "Edit Analysis") {
                beginAnalysisEdit()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isEditingAnalysis)
        }
        .cardStyle()
    }

    private func checklistRow(_ title: String, complete: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(complete ? Color.primaryYellow : Color.richBlack.opacity(0.35))
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(complete ? 1 : 0.65))
            Spacer()
        }
    }

    private var analysisEditSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Analysis Lab")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            LabeledTextField(title: "Address", text: $address, keyboard: .default)
            HStack(spacing: 10) {
                LabeledTextField(title: "City", text: $city, keyboard: .default)
                LabeledTextField(title: "State", text: $state, keyboard: .default)
                    .onChange(of: state) { _, newValue in
                        state = StateAbbreviationFormatter.abbreviate(newValue)
                    }
                LabeledTextField(title: "ZIP", text: $zipCode, keyboard: .numberPad)
            }

            LabeledTextField(title: "Purchase Price", text: $purchasePrice, keyboard: .decimalPad)
                .onChange(of: purchasePrice) { _, newValue in
                    purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                }
            HStack(spacing: 10) {
                LabeledTextField(title: "Down Payment %", text: $downPaymentPercent, keyboard: .decimalPad)
                    .onChange(of: downPaymentPercent) { _, newValue in
                        downPaymentPercent = InputFormatters.sanitizeDecimal(newValue)
                    }
                LabeledTextField(title: "Interest %", text: $interestRate, keyboard: .decimalPad)
                    .onChange(of: interestRate) { _, newValue in
                        interestRate = InputFormatters.sanitizeDecimal(newValue)
                    }
            }

            Picker("Loan Term", selection: $loanTermYears) {
                Text("15 years").tag(15)
                Text("20 years").tag(20)
                Text("30 years").tag(30)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("Grade Profile")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                Picker("Grade Profile", selection: $selectedProfileId) {
                    let defaultName = gradeProfileStore.profiles.first(where: { $0.id == gradeProfileStore.defaultProfileId })?.name ?? "Default"
                    Text("Default (\(defaultName))").tag(Optional<String>.none)
                    ForEach(gradeProfileStore.profiles, id: \.id) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
            }

            ExpenseModuleView(
                module: expenseModule,
                annualCashFlow: analysisMetrics?.annualCashFlow,
                mode: $expenseMode,
                simpleRate: $simpleExpenseRate,
                annualTaxes: $annualTaxes,
                annualInsurance: $annualInsurance,
                managementFee: $managementFee,
                maintenanceReserves: $maintenanceReserves
            )

            LabeledTextField(title: "Reno Budget (Optional)", text: $renoBudget, keyboard: .decimalPad)
                .onChange(of: renoBudget) { _, newValue in
                    renoBudget = InputFormatters.formatCurrencyLive(newValue)
                }

            RentRollEditorView(
                units: $rentRollInputs,
                style: .full,
                allowsUnitType: true,
                requiresValidRentRow: true
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Capex Items (Optional)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Text(Formatters.currency.string(from: NSNumber(value: capexInputs.reduce(0) { $0 + (InputFormatters.parseCurrency($1.amount) ?? 0) })) ?? "$0")
                        .font(.system(.footnote, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.75))
                }

                ForEach($capexInputs) { $item in
                    HStack(spacing: 8) {
                        LabeledTextField(title: "Name", text: $item.name, keyboard: .default)
                        LabeledTextField(title: "Amount", text: $item.amount, keyboard: .decimalPad)
                            .onChange(of: item.amount) { _, newValue in
                                item.amount = InputFormatters.formatCurrencyLive(newValue)
                            }
                    }
                }

                HStack(spacing: 10) {
                    Button("Add Capex Item") {
                        capexInputs.append(CapexItemInput(name: "", amount: ""))
                    }
                    .font(.system(.footnote, design: .rounded).weight(.semibold))

                    if !capexInputs.isEmpty {
                        Button("Clear") {
                            capexInputs.removeAll()
                        }
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    showDiscardChangesConfirm = true
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.richBlack.opacity(0.2), lineWidth: 1)
                )

                Button(isSavingAnalysis ? "Saving..." : "Save Analysis") {
                    Task { await saveAnalysisChanges() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSavingAnalysis)
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

        guard let metrics = analysisMetrics else {
            exportError = "Add financing inputs to export the report."
            isExporting = false
            return
        }

        let image = await ImageLoader.loadImage(from: activeProperty.imageURL)

        do {
            let profile = gradeProfileStore.effectiveProfile(for: activeProperty)
            let url = try PDFService.renderDealSummary(
                property: activeProperty,
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
        guard let metrics = analysisMetrics,
              let breakdown = mortgageBreakdown else {
            return nil
        }

        let appreciation = activeProperty.appreciationRate ?? 0
        return EvaluatorEngine.evaluate(
            purchasePrice: activeProperty.purchasePrice,
            annualCashFlow: metrics.annualCashFlow,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: appreciation,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            marginalTaxRate: activeProperty.marginalTaxRate,
            landValuePercent: activeProperty.landValuePercent
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

    private func beginAnalysisEdit() {
        isEditingAnalysis = true
        inlineRentRollError = nil
        let source = activeProperty
        address = source.address
        city = source.city ?? ""
        state = source.state ?? ""
        zipCode = source.zipCode ?? ""
        purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: source.purchasePrice)) ?? String(source.purchasePrice)
        downPaymentPercent = source.downPaymentPercent.map { String(format: "%.2f", $0) } ?? ""
        interestRate = source.interestRate.map { String(format: "%.2f", $0) } ?? ""
        annualTaxes = source.annualTaxes.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? ""
        annualInsurance = source.annualInsurance.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? ""
        loanTermYears = source.loanTermYears ?? 30
        rentRollInputs = source.rentRoll.map {
            RentUnitInput(
                monthlyRent: Formatters.currencyTwo.string(from: NSNumber(value: $0.monthlyRent)) ?? String($0.monthlyRent),
                unitType: $0.unitType,
                bedrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bedrooms)) ?? String($0.bedrooms),
                bathrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bathrooms)) ?? String($0.bathrooms),
                squareFeet: $0.squareFeet.map { String(Int($0)) } ?? ""
            )
        }
        if rentRollInputs.isEmpty {
            rentRollInputs = [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")]
        }

        let isStandard = source.useStandardOperatingExpense ?? true
        expenseMode = isStandard ? .simple : .detailed
        simpleExpenseRate = String(format: "%.2f", source.operatingExpenseRate ?? standardOperatingExpenseRate)
        managementFee = ""
        maintenanceReserves = ""
        if let expenses = source.operatingExpenses {
            if let mgmt = expenses.first(where: { $0.name.localizedCaseInsensitiveContains("management") })?.annualAmount {
                managementFee = Formatters.currencyTwo.string(from: NSNumber(value: mgmt)) ?? String(mgmt)
            }
            if let maint = expenses.first(where: { $0.name.localizedCaseInsensitiveContains("maintenance") || $0.name.localizedCaseInsensitiveContains("repair") })?.annualAmount {
                maintenanceReserves = Formatters.currencyTwo.string(from: NSNumber(value: maint)) ?? String(maint)
            }
        }
        selectedProfileId = source.gradeProfileId
        renoBudget = source.renoBudget.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? ""
        capexInputs = (source.capexItems ?? []).map {
            CapexItemInput(
                name: $0.name,
                amount: Formatters.currencyTwo.string(from: NSNumber(value: $0.annualAmount)) ?? String($0.annualAmount)
            )
        }
        applyRentToAll = ""
        exportError = nil
    }

    private func syncInlineRentRollInputs(from property: Property) {
        inlineRentRollAutosaveTask?.cancel()
        inlineRentRollInputs = property.rentRoll.map {
            RentUnitInput(
                monthlyRent: Formatters.currencyTwo.string(from: NSNumber(value: $0.monthlyRent)) ?? String($0.monthlyRent),
                unitType: $0.unitType,
                bedrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bedrooms)) ?? String($0.bedrooms),
                bathrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bathrooms)) ?? String($0.bathrooms),
                squareFeet: $0.squareFeet.map { String(Int($0)) } ?? ""
            )
        }
        if inlineRentRollInputs.isEmpty {
            inlineRentRollInputs = [RentUnitInput(monthlyRent: "", unitType: "Unit 1", bedrooms: "", bathrooms: "", squareFeet: "")]
        }
        inlineRentRollIsValid = RentRollEditorView.hasAtLeastOneValidRentRow(inlineRentRollInputs)
        inlineRentRollLastSavedFingerprint = rentRollFingerprint(property.rentRoll)
    }

    private func scheduleInlineRentRollAutosave() {
        inlineRentRollAutosaveTask?.cancel()
        guard !isEditingAnalysis else { return }
        guard inlineRentRollIsValid else {
            inlineRentRollError = nil
            return
        }

        let units = RentRollEditorView.validUnits(from: inlineRentRollInputs)
        guard !units.isEmpty else { return }
        let fingerprint = rentRollFingerprint(units)
        guard fingerprint != inlineRentRollLastSavedFingerprint else {
            inlineRentRollError = nil
            return
        }

        inlineRentRollAutosaveTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await saveInlineRentRoll(units: units, fingerprint: fingerprint)
        }
    }

    private func saveInlineRentRoll(units: [RentUnit], fingerprint: String) async {
        inlineRentRollError = nil
        guard !isEditingAnalysis else {
            return
        }
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            inlineRentRollError = "Property was not found. Reload and try again."
            return
        }
        guard fingerprint != inlineRentRollLastSavedFingerprint else {
            return
        }

        inlineRentRollIsSaving = true
        var updated = propertyStore.properties[index]
        updated.rentRoll = units
        updated.missingAnalysisInputs = missingAnalysisInputs(for: updated)
        updated.analysisCompleteness = analysisCompletenessState(for: updated).rawValue

        do {
            try await propertyStore.updateProperty(updated)
            inlineRentRollLastSavedFingerprint = fingerprint
        } catch {
            inlineRentRollError = error.localizedDescription
        }
        inlineRentRollIsSaving = false
    }

    private func rentRollFingerprint(_ units: [RentUnit]) -> String {
        units.map {
            [
                String(format: "%.2f", $0.monthlyRent),
                $0.unitType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                String(format: "%.2f", $0.bedrooms),
                String(format: "%.2f", $0.bathrooms),
                $0.squareFeet.map { String(format: "%.0f", $0) } ?? ""
            ].joined(separator: "|")
        }
        .joined(separator: "||")
    }

    private var draftRentUnits: [RentUnit]? {
        let units = RentRollEditorView.validUnits(from: rentRollInputs)
        return units.isEmpty ? nil : units
    }

    private var expenseModule: MFMetricEngine.ExpenseModule? {
        let price = InputFormatters.parseCurrency(purchasePrice) ?? activeProperty.purchasePrice
        let rentUnits = (isEditingAnalysis ? draftRentUnits : nil) ?? activeProperty.rentRoll
        let grossAnnualRent = rentUnits.reduce(0) { $0 + $1.monthlyRent } * 12
        guard grossAnnualRent >= 0 else { return nil }
        return MFMetricEngine.ExpenseModule(
            purchasePrice: price,
            unitCount: rentUnits.count,
            grossAnnualRent: grossAnnualRent,
            annualTaxes: InputFormatters.parseCurrency(annualTaxes) ?? activeProperty.annualTaxes,
            annualInsurance: InputFormatters.parseCurrency(annualInsurance) ?? activeProperty.annualInsurance,
            mgmtFee: InputFormatters.parseCurrency(managementFee),
            maintenanceReserves: InputFormatters.parseCurrency(maintenanceReserves)
        )
    }

    private var analysisMetrics: DealMetrics? {
        if isEditingAnalysis {
            guard let draft = draftProperty else { return nil }
            guard let module = expenseModule else { return MetricsEngine.computeMetrics(property: draft) }

            if expenseMode == .detailed,
               let downPayment = draft.downPaymentPercent,
               let interest = draft.interestRate {
                let debtService = MetricsEngine.mortgageBreakdown(
                    purchasePrice: draft.purchasePrice,
                    downPaymentPercent: downPayment,
                    interestRate: interest,
                    loanTermYears: Double(draft.loanTermYears ?? 30),
                    annualTaxes: module.effectiveAnnualTaxes,
                    annualInsurance: module.effectiveAnnualInsurance
                ).map { $0.annualPrincipal + $0.annualInterest } ?? 0

                let noi = module.netOperatingIncome
                let annualCashFlow = noi - debtService
                let downPaymentAmount = max(draft.purchasePrice * (downPayment / 100.0), 0.0001)
                let capRate = draft.purchasePrice > 0 ? noi / draft.purchasePrice : 0
                let cashOnCash = annualCashFlow / downPaymentAmount
                let dcr = debtService > 0 ? noi / debtService : 0

                return DealMetrics(
                    totalAnnualRent: module.grossAnnualRent,
                    netOperatingIncome: noi,
                    capRate: capRate,
                    annualDebtService: debtService,
                    annualCashFlow: annualCashFlow,
                    cashOnCash: cashOnCash,
                    debtCoverageRatio: dcr,
                    grade: MetricsEngine.gradeFor(cashOnCash: cashOnCash, dcr: dcr)
                )
            }

            return MetricsEngine.computeMetrics(property: draft)
        }
        return MetricsEngine.computeMetrics(property: activeProperty)
    }

    private var draftProperty: Property? {
        guard isEditingAnalysis else { return nil }
        guard let purchaseValue = InputFormatters.parseCurrency(purchasePrice),
              let taxesValue = InputFormatters.parseCurrency(annualTaxes),
              let insuranceValue = InputFormatters.parseCurrency(annualInsurance),
              let rentUnits = draftRentUnits else { return nil }

        var property = activeProperty
        property.address = address
        property.city = city.isEmpty ? nil : city
        property.state = state.isEmpty ? nil : state
        property.zipCode = zipCode.isEmpty ? nil : zipCode
        property.purchasePrice = purchaseValue
        property.rentRoll = rentUnits
        property.useStandardOperatingExpense = expenseMode == .simple
        property.operatingExpenseRate = Double(simpleExpenseRate) ?? standardOperatingExpenseRate
        property.operatingExpenses = expenseMode == .detailed ? [
            OperatingExpenseItem(name: "Management Fee", annualAmount: expenseModule?.effectiveManagementFee ?? 0),
            OperatingExpenseItem(name: "Maintenance Reserves", annualAmount: expenseModule?.effectiveMaintenanceReserves ?? 0)
        ] : []
        property.annualTaxes = taxesValue
        property.annualInsurance = insuranceValue
        property.loanTermYears = loanTermYears
        property.downPaymentPercent = Double(downPaymentPercent)
        property.interestRate = Double(interestRate)
        property.gradeProfileId = selectedProfileId
        property.renoBudget = InputFormatters.parseCurrency(renoBudget)
        property.capexItems = capexInputs.compactMap { item in
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let amount = InputFormatters.parseCurrency(item.amount) else { return nil }
            return OperatingExpenseItem(name: item.name, annualAmount: amount)
        }
        property.missingAnalysisInputs = missingAnalysisInputs(for: property)
        property.analysisCompleteness = analysisCompletenessState(for: property).rawValue
        return property
    }

    private func saveAnalysisChanges() async {
        guard let updated = draftProperty else {
            exportError = "Complete required fields before saving."
            return
        }

        isSavingAnalysis = true
        defer { isSavingAnalysis = false }
        do {
            try await propertyStore.updateProperty(updated)
            isEditingAnalysis = false
            exportError = nil
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteProperty() async {
        do {
            try await propertyStore.deleteProperty(activeProperty)
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
            }
        }
    }

    @MainActor

    private func openInMaps() {
        guard let coordinate = mapCoordinate else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = activeProperty.address
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        ])
    }

    private func fetchMapSnapshot() async {
        if mapSnapshotURL != nil { return }
        let addressParts = [activeProperty.address, activeProperty.city, activeProperty.state, activeProperty.zipCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let fullAddress = addressParts.joined(separator: ", ")
        guard !fullAddress.isEmpty else { return }

        isLoadingMap = true
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(fullAddress)
            if let coordinate = placemarks.first?.location?.coordinate {
                mapCoordinate = coordinate
                let url = try await MapSnapshotService.snapshotURL(for: coordinate, title: activeProperty.address)
                mapSnapshotURL = url
            }
        } catch {
            mapSnapshotURL = nil
        }
        isLoadingMap = false
    }

    private func usesFallbackRent(for property: Property) -> Bool {
        !property.rentRoll.contains(where: { $0.monthlyRent > 0 })
    }

    private func hasCompletedRentRoll(for property: Property) -> Bool {
        property.rentRoll.contains { $0.monthlyRent > 0 }
    }

    private func hasCapexData(for property: Property) -> Bool {
        let capexTotal = (property.capexItems ?? []).reduce(0) { $0 + $1.annualAmount }
        return (property.renoBudget ?? 0) > 0 || capexTotal > 0
    }

    private func hasReviewedExpenses(for property: Property) -> Bool {
        !(property.useStandardOperatingExpense ?? true)
    }

    private func missingAnalysisInputs(for property: Property) -> [String] {
        var missing: [String] = []
        if !hasCompletedRentRoll(for: property) { missing.append("rent_roll") }
        if !hasCapexData(for: property) { missing.append("capex_reno") }
        if !hasReviewedExpenses(for: property) { missing.append("review_expenses") }
        return missing
    }

    private func analysisCompletenessState(for property: Property) -> Property.AnalysisCompletenessState {
        let missing = missingAnalysisInputs(for: property)
        if missing.isEmpty {
            return .fullComplete
        }
        if missing == ["capex_reno"] {
            return .coreComplete
        }
        return .provisional
    }

    private func annualizedCapex(for property: Property) -> Double {
        let annualCapex = (property.capexItems ?? []).reduce(0) { $0 + $1.annualAmount }
        let annualizedReno = (property.renoBudget ?? 0) / 5.0
        return annualCapex + annualizedReno
    }

    private var activeProperty: Property {
        if isEditingAnalysis, let draftProperty {
            return draftProperty
        }
        guard let id = property.id else { return property }
        return propertyStore.properties.first { $0.id == id } ?? property
    }

    private var weightedGrade: Grade {
        guard let metrics = analysisMetrics,
              let downPayment = activeProperty.downPaymentPercent,
              let interestRate = activeProperty.interestRate,
              let breakdown = MetricsEngine.mortgageBreakdown(
                purchasePrice: activeProperty.purchasePrice,
                downPaymentPercent: downPayment,
                interestRate: interestRate,
                loanTermYears: Double(activeProperty.loanTermYears ?? 30),
                annualTaxes: activeProperty.annualTaxes ?? (activeProperty.annualTaxesInsurance ?? 0),
                annualInsurance: activeProperty.annualInsurance ?? 0
              ) else {
            return analysisMetrics?.grade ?? .dOrF
        }
        let profile = gradeProfileStore.effectiveProfile(for: activeProperty)
        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: activeProperty.purchasePrice,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: activeProperty.appreciationRate ?? 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private var activeProfile: GradeProfile {
        gradeProfileStore.effectiveProfile(for: activeProperty)
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
        var updated = activeProperty
        updated.gradeProfileId = profileId
        if let index = propertyStore.properties.firstIndex(where: { $0.id == updated.id }) {
            propertyStore.properties[index] = updated
        }
        do {
            try await propertyStore.updateProperty(updated)
        } catch { }
    }

    private var mortgageBreakdown: MortgageBreakdown? {
        guard let downPayment = activeProperty.downPaymentPercent,
              let interest = activeProperty.interestRate else { return nil }
        let taxes = activeProperty.annualTaxes ?? (activeProperty.annualTaxesInsurance ?? 0)
        let insurance = activeProperty.annualInsurance ?? 0
        let term = Double(termOverride ?? activeProperty.loanTermYears ?? 30)
        return MetricsEngine.mortgageBreakdown(
            purchasePrice: activeProperty.purchasePrice,
            downPaymentPercent: downPayment,
            interestRate: interest,
            loanTermYears: term,
            annualTaxes: taxes,
            annualInsurance: insurance
        )
    }

    private var totalBeds: Double {
        activeProperty.rentRoll.reduce(0) { $0 + $1.bedrooms }
    }

    private var totalBaths: Double {
        activeProperty.rentRoll.reduce(0) { $0 + $1.bathrooms }
    }
}

private struct CapexItemInput: Identifiable {
    let id = UUID()
    var name: String
    var amount: String
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
