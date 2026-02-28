import SwiftUI
import Charts
import UIKit
import PhotosUI
import MapKit

struct PropertyDetailView: View {
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    @AppStorage("cashflowBreakEvenThreshold") private var cashflowBreakEvenThreshold = 500.0
    @AppStorage("defaultMonthlyRentPerUnit") private var defaultMonthlyRentPerUnit = 1500.0
    @AppStorage("defaultClosingCostRate") private var defaultClosingCostRate = 3.0
    @AppStorage("dashboardSelectedTab") private var dashboardSelectedTab = 0
    @AppStorage("collaborationFocusPropertyId") private var collaborationFocusPropertyId = ""
    @Environment(\.dismiss) private var dismiss
    let property: Property
    var cardHeroNamespace: Namespace.ID? = nil
    var cardHeroID: String? = nil

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
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoSourcePopover = false
    @State private var showPhotoLibraryPicker = false
    @State private var showCamera = false
    @State private var isUploadingImage = false
    @State private var photoUploadError: String?
    @State private var inlineRentRollInputs: [RentUnitInput] = []
    @State private var inlineRentRollIsValid = false
    @State private var inlineRentRollIsSaving = false
    @State private var inlineRentRollError: String?
    @State private var inlineRentRollAutosaveTask: Task<Void, Never>?
    @State private var inlineRentRollLastSavedFingerprint = ""
    @State private var selectedPillarResult: PillarResult?
    @State private var showingMortgageDetails = false
    @State private var showingCashToCloseLab = false
    @State private var isEditingExpenses = false
    @State private var isSavingExpenses = false
    @State private var expenseSaveError: String?
    @State private var marginalTaxRateInput = ""
    @State private var landValuePercentInput = ""
    @State private var isSavingTaxAssumptions = false
    @State private var taxAssumptionError: String?
    @State private var isOwnedToggle = false
    @State private var isSavingOwnership = false
    @State private var ownershipError: String?
    @State private var isSavingBasics = false
    @State private var basicsSaveError: String?
    @State private var isPropertyBasicsExpanded = false
    @StateObject private var locationSearchService = LocationSearchService()
    @State private var isApplyingAddressSelection = false
    @State private var marketInsightSnapshot: MarketInsightSnapshot?
    @State private var isLoadingMarketInsights = false
    @State private var showMarketInsightPaywall = false
    @State private var marketInsightError: String?
    @State private var rentAVMSnapshot: MarketInsightsService.RentalMarketAVMSnapshot?
    @StateObject private var scenarioCompareStore = ScenarioCompareStore()
    @State private var scenarioSort: ScenarioSortOption = .grade
    @State private var scenarioActionError: String?
    @State private var didOpenPaywallFromScenario = false
    @State private var isSavingScenario = false
    @State private var showScenarioNameSheet = false
    @State private var pendingScenarioDefaultName = ""
    @State private var scenarioToDelete: PropertyScenario?
    @State private var isScenarioCompareExpanded = true
    @State private var hasTrackedScenarioOpenForPropertyId: String?
    @StateObject private var offerTrackerStore = OfferTrackerStore()
    @State private var showOfferDetailSheet = false
    @State private var offerActionError: String?
    @State private var didOpenPaywallFromOfferTracker = false
    @State private var showDeepDive = false
    @State private var persistedPropertySnapshot: Property?
    @State private var marketInsightLoadKey: String?
    @State private var maoDesiredProfitPercent = 12.0
    @State private var maoFixedCostPercent = 2.0
    @State private var maoSellingCostPercent = 8.0

    private let marketInsightsService = MarketInsightsService()
    private let enableMarketInsightsUI = true

    var body: some View {
        bodyContent
    }

    private var bodyContent: some View {
        var view = AnyView(rootWithHero)
        view = AnyView(view.navigationTitle("").navigationBarTitleDisplayMode(.inline))
        view = AnyView(view.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) { showDeleteConfirm = true } label: { Image(systemName: "trash") }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    openDealRoom()
                } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Open deal room")

                Button { showDeepDive = true } label: { Image(systemName: "rectangle.and.text.magnifyingglass") }
                    .accessibilityLabel("Open deep dive")
                Button { Task { await exportPDF() } } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(isExporting)
                    .accessibilityLabel("Export deal summary")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.primaryYellow)
            }
        })
        view = AnyView(view.sheet(isPresented: $showShare) { if let shareURL { ActivityView(activityItems: [shareURL]) } })
        view = AnyView(view.sheet(item: $infoMetric) { MetricInfoSheet(metric: $0) })
        view = AnyView(view.sheet(item: $selectedPillarResult) {
            PillarDetailSheet(result: $0)
                .presentationDetents([.height(pillarSheetHeight(for: $0))])
                .presentationDragIndicator(.visible)
        })
        view = AnyView(view.fullScreenCover(isPresented: $showingMortgageDetails) {
            if mortgageBreakdown != nil {
                MortgageDetailSheet(
                    purchasePrice: activeProperty.purchasePrice,
                    baseline: MortgageScenarioValues(
                        downPaymentPercent: activeProperty.downPaymentPercent ?? 25,
                        interestRate: activeProperty.interestRate ?? 6.0,
                        annualTaxes: activeProperty.annualTaxes ?? (activeProperty.annualTaxesInsurance ?? 0),
                        annualInsurance: activeProperty.annualInsurance ?? 0,
                        termYears: termOverride ?? activeProperty.loanTermYears ?? 30
                    ),
                    baselineMetrics: MetricsEngine.computeMetrics(property: activeProperty),
                    baselineGrade: weightedGrade(for: activeProperty),
                    evaluateScenario: { scenario in
                        var scenarioProperty = activeProperty
                        scenarioProperty.downPaymentPercent = scenario.downPaymentPercent
                        scenarioProperty.interestRate = scenario.interestRate
                        scenarioProperty.annualTaxes = scenario.annualTaxes
                        scenarioProperty.annualInsurance = scenario.annualInsurance
                        scenarioProperty.loanTermYears = scenario.termYears
                        return evaluatedMetricsAndGrade(for: scenarioProperty)
                    }
                ) { applyMortgageScenario($0) }
            }
        })
        view = AnyView(view.sheet(isPresented: $showingCashToCloseLab) {
            CashToCloseLabSheet(
                purchasePrice: activeProperty.purchasePrice,
                baseline: CashToCloseScenarioValues(
                    downPaymentPercent: activeProperty.downPaymentPercent ?? 25,
                    closingCostRate: defaultClosingCostRate,
                    renoReserve: activeProperty.renoBudget ?? 0
                ),
                baselineMetrics: MetricsEngine.computeMetrics(property: activeProperty),
                baselineGrade: weightedGrade(for: activeProperty),
                evaluateScenario: { evaluateCashToCloseScenario($0) }
            ) { applyCashToCloseScenario($0) }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        })
        view = AnyView(view.sheet(isPresented: $showCamera) {
            CameraPicker { image in Task { await uploadDetailImage(image) } }
        })
        view = AnyView(view.sheet(isPresented: $showMarketInsightPaywall) {
            PaywallView().environmentObject(subscriptionManager)
        })
        view = AnyView(view.sheet(isPresented: $showScenarioNameSheet) {
            ScenarioNameSheet(
                name: $pendingScenarioDefaultName,
                onCancel: { showScenarioNameSheet = false },
                onSave: { Task { await saveScenario(named: pendingScenarioDefaultName) } }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        })
        view = AnyView(view.sheet(isPresented: $showOfferDetailSheet) {
            OfferDetailSheet(
                store: offerTrackerStore,
                property: liveDisplayProperty,
                isPremium: subscriptionManager.isPremium,
                onRequireUpgrade: {
                    didOpenPaywallFromOfferTracker = true
                    showMarketInsightPaywall = true
                },
                onTrackEvent: { event, metadata in
                    AnalyticsTracker.track(event, metadata: metadata)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        })
        view = AnyView(view.fullScreenCover(isPresented: $showDeepDive) {
            NavigationStack {
                PropertyDeepDiveView(property: activeProperty)
                    .environmentObject(subscriptionManager)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showDeepDive = false }
                        }
                    }
            }
        })
        view = AnyView(view.photosPicker(isPresented: $showPhotoLibraryPicker, selection: $selectedPhotoItem, matching: .images))
        view = AnyView(view.onAppear {
            syncPersistedSnapshot()
            simpleExpenseRate = String(standardOperatingExpenseRate)
            syncBasicInputs(from: activeProperty)
            syncInlineRentRollInputs(from: activeProperty)
            syncTaxAssumptionsInputs(from: activeProperty)
            isOwnedToggle = activeProperty.isOwned == true
            offerTrackerStore.setPremium(subscriptionManager.isPremium)
            bindOfferStore()
            bindScenarioStore()
            if enableMarketInsightsUI {
                let nextKey = [activeProperty.zipCode ?? "", activeProperty.city ?? "", activeProperty.state ?? "", activeProperty.address]
                    .joined(separator: "|")
                    .lowercased()
                if marketInsightLoadKey != nextKey {
                    marketInsightLoadKey = nextKey
                    Task { await loadMarketInsightsIfNeeded() }
                }
            }
        })
        view = AnyView(view.onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadDetailImage(image)
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        })
        view = AnyView(view.onChange(of: activeProperty.id) { _, _ in
            if !isEditingAnalysis {
                syncBasicInputs(from: activeProperty)
                syncInlineRentRollInputs(from: activeProperty)
                syncTaxAssumptionsInputs(from: activeProperty)
                isOwnedToggle = activeProperty.isOwned == true
            }
            bindOfferStore()
            bindScenarioStore()
        })
        view = AnyView(view.onChange(of: activeProperty.rentRoll) { _, _ in
            guard !isEditingAnalysis else { return }
            syncInlineRentRollInputs(from: activeProperty)
        })
        view = AnyView(view.onChange(of: activeProperty.marginalTaxRate) { _, _ in
            guard !isSavingTaxAssumptions else { return }
            syncTaxAssumptionsInputs(from: activeProperty)
        })
        view = AnyView(view.onChange(of: activeProperty.landValuePercent) { _, _ in
            guard !isSavingTaxAssumptions else { return }
            syncTaxAssumptionsInputs(from: activeProperty)
        })
        view = AnyView(view.onChange(of: inlineRentRollInputs) { _, _ in
            scheduleInlineRentRollAutosave()
        })
        view = AnyView(view.onDisappear {
            inlineRentRollAutosaveTask?.cancel()
            offerTrackerStore.stop()
            Task { await scenarioCompareStore.detach() }
        })
        view = AnyView(view.onChange(of: subscriptionManager.isPremium) { _, isPremium in
            offerTrackerStore.setPremium(isPremium)
            if isPremium && didOpenPaywallFromScenario {
                AnalyticsTracker.track(.proUpgradeSuccessFromScenarioCompare, metadata: ["property_id": activeProperty.id ?? "unknown"])
                didOpenPaywallFromScenario = false
            }
            if isPremium && didOpenPaywallFromOfferTracker {
                AnalyticsTracker.track(.proUpgradeSuccessFromOfferTracker, metadata: ["property_id": activeProperty.id ?? "unknown"])
                didOpenPaywallFromOfferTracker = false
            }
        })
        view = AnyView(view.alert("Delete Property?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                dismiss()
                Task { await deleteProperty() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove the property from your portfolio.")
        })
        view = AnyView(view.alert("Unable to delete", isPresented: Binding(get: { deleteError != nil }, set: { _ in deleteError = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "Unknown error")
        })
        view = AnyView(view.alert("Action failed", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError ?? "Unknown error")
        })
        view = AnyView(view.alert("Unable to open offer tools", isPresented: Binding(get: { offerActionError != nil }, set: { _ in offerActionError = nil })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(offerActionError ?? "Unknown error")
        })
        view = AnyView(view.confirmationDialog("Discard unsaved analysis changes?", isPresented: $showDiscardChangesConfirm, titleVisibility: .visible) {
            Button("Discard Changes", role: .destructive) {
                isEditingAnalysis = false
                exportError = nil
            }
            Button("Keep Editing", role: .cancel) { }
        })
        view = AnyView(view.alert("Delete Scenario?", isPresented: Binding(get: { scenarioToDelete != nil }, set: { isPresented in
            if !isPresented { scenarioToDelete = nil }
        })) {
            Button("Delete", role: .destructive) {
                guard let scenario = scenarioToDelete else { return }
                Task { await deleteScenario(scenario) }
            }
            Button("Cancel", role: .cancel) {
                scenarioToDelete = nil
            }
        } message: {
            Text("This will permanently remove the saved scenario.")
        })
        return view
    }

    private var rootWithHero: AnyView {
        if let cardHeroNamespace, let cardHeroID {
            return AnyView(
                detailRoot
                    .matchedGeometryEffect(id: cardHeroID, in: cardHeroNamespace)
            )
        } else {
            return AnyView(detailRoot)
        }
    }

    private var detailRoot: some View {
        ZStack {
            CanvasBackground()

            VStack(spacing: 0) {
                commandHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                propertyActionChipRow
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        propertyBasicsSection.erasedToAnyView()
                        if shouldShowCompleteAnalysisSection {
                            completeAnalysisSection.erasedToAnyView()
                        }
                        ownershipSection.erasedToAnyView()
                        mediaActionChipsRow.erasedToAnyView()
                        summarySection.erasedToAnyView()
                        scenarioCompareSection.erasedToAnyView()
                        maximumAllowableOfferSection.erasedToAnyView()
                        pillarsSection.erasedToAnyView()
                        taxAssumptionsSection.erasedToAnyView()
                        mortgageSection.erasedToAnyView()
                        cashToCloseSection.erasedToAnyView()
                        if isEditingAnalysis {
                            analysisEditSection.erasedToAnyView()
                        }
                        operatingExpenseSection.erasedToAnyView()
                        if enableMarketInsightsUI {
                            marketInsightsSection.erasedToAnyView()
                        }
                        rentRollSection.erasedToAnyView()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var commandHeader: some View {
        PropertyCommandHeaderView(
            address: activeProperty.address,
            grade: weightedGrade,
            monthlyCashFlow: (analysisMetrics?.annualCashFlow ?? 0) / 12.0,
            profileName: activeProfile.name,
            profileColorHex: activeProfile.colorHex,
            unitCount: effectiveUnitCount
        )
    }

    private var activeTrackedOffer: PropertyOffer? {
        offerTrackerStore.offers.first(where: { $0.isActive }) ?? offerTrackerStore.selectedOffer
    }

    private var offerChipSubtitle: String {
        guard let offer = activeTrackedOffer else { return "Track terms" }
        if let nextDeadline = nearestDeadlineSummary(for: offer) {
            return nextDeadline.isUrgent ? "Due soon" : nextDeadline.label
        }
        return offer.status.title
    }

    private var offerChipStatusColor: Color {
        guard let offer = activeTrackedOffer else { return Color.primaryYellow }
        switch offer.status {
        case .accepted:
            return .green
        case .rejected, .withdrawn, .expired:
            return .red
        case .submitted, .counterReceived:
            return Color.blue.opacity(0.85)
        case .draft, .readyToSubmit:
            return Color.primaryYellow
        }
    }

    private var offerChipBadgeText: String? {
        guard let offer = activeTrackedOffer else { return "New" }
        if let nextDeadline = nearestDeadlineSummary(for: offer), nextDeadline.isUrgent {
            return "Due Soon"
        }
        if let revision = offerTrackerStore.currentRevision {
            return "R\(revision.revisionNumber)"
        }
        return offer.status.title
    }

    private var offerChipIsEmphasized: Bool {
        activeTrackedOffer != nil
    }

    private var propertyActionChipRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Capsule(style: .continuous)
                    .fill(Color.primaryYellow)
                    .frame(width: 30, height: 4)

                Text("Deal Tools")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack.opacity(0.62))
            }

            Text("Open the offer flow, save scenarios, and launch deeper analysis.")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.62))

            DealToolChipStrip(chips: [
                DealToolChipModel(
                    id: "offer",
                    icon: "doc.text.magnifyingglass",
                    title: "Offer",
                    subtitle: offerChipSubtitle,
                    statusColor: offerChipStatusColor,
                    badgeText: offerChipBadgeText,
                    isEmphasized: offerChipIsEmphasized,
                    isLocked: false
                ) {
                    AnalyticsTracker.track(.offerChipTapped, metadata: ["property_id": activeProperty.id ?? "unsaved"])
                    guard !(activeProperty.id ?? "").isEmpty else {
                        offerActionError = "Save the property first to create an offer."
                        return
                    }
                    bindOfferStore()
                    showOfferDetailSheet = true
                },
                DealToolChipModel(
                    id: "scenario",
                    icon: "square.split.2x2",
                    title: "Scenario",
                    subtitle: scenarioCompareStore.scenarios.isEmpty ? "Save current" : "Compare runs",
                    statusColor: nil,
                    badgeText: scenarioCompareStore.scenarios.isEmpty ? nil : "\(scenarioCompareStore.scenarios.count)",
                    isEmphasized: !scenarioCompareStore.scenarios.isEmpty,
                    isLocked: false
                ) {
                    pendingScenarioDefaultName = "Scenario \(scenarioCompareStore.scenarios.count + 1)"
                    showScenarioNameSheet = true
                },
                DealToolChipModel(
                    id: "deep_dive",
                    icon: "rectangle.and.text.magnifyingglass",
                    title: "Deep Dive",
                    subtitle: persistedPropertySnapshot == nil ? "Records" : "Loaded",
                    statusColor: nil,
                    badgeText: nil,
                    isEmphasized: persistedPropertySnapshot != nil,
                    isLocked: false
                ) {
                    showDeepDive = true
                },
                DealToolChipModel(
                    id: "share",
                    icon: "square.and.arrow.up",
                    title: "Share",
                    subtitle: "Deal PDF",
                    statusColor: nil,
                    badgeText: nil,
                    isEmphasized: false,
                    isLocked: false
                ) {
                    Task { await exportPDF() }
                }
            ])
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primaryYellow.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var mediaActionChipsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                mapChip
                photoChip
                Spacer()
            }
            if let photoUploadError {
                Text(photoUploadError)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var propertyBasicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPropertyBasicsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Property Basics")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Image(systemName: isPropertyBasicsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.richBlack.opacity(0.65))
                }
            }
            .buttonStyle(.plain)

            if isPropertyBasicsExpanded {
                LabeledTextField(title: "Address", text: $address, keyboard: .default)
                    .onChange(of: address) { _, newValue in
                        updateBasicAddressAutocompleteQuery(with: newValue)
                    }

                basicAutoFillAddressButton

                if shouldShowBasicAddressSuggestions {
                    basicAddressSuggestionsView
                }

                HStack(spacing: 10) {
                    LabeledTextField(title: "City", text: $city, keyboard: .default)
                    LabeledTextField(title: "State", text: $state, keyboard: .default)
                        .onChange(of: state) { _, newValue in
                            state = StateAbbreviationFormatter.abbreviate(newValue)
                        }
                    LabeledTextField(title: "ZIP", text: $zipCode, keyboard: .numberPad)
                        .onChange(of: zipCode) { _, newValue in
                            zipCode = String(newValue.filter(\.isNumber).prefix(5))
                        }
                }

                LabeledTextField(title: "Purchase Price", text: $purchasePrice, keyboard: .decimalPad)
                    .onChange(of: purchasePrice) { _, newValue in
                        purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                    }

                if let basicsSaveError {
                    Text(basicsSaveError)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                }

                Button(isSavingBasics ? "Saving..." : "Save Basics") {
                    Task { await saveBasicDetails() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSavingBasics)
            }
        }
        .cardStyle()
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: isOwnedToggle ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOwnedToggle ? Color.primaryYellow : Color.richBlack.opacity(0.45))

                Text("Owned Property")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)

                Spacer()

                Toggle("", isOn: ownedToggleBinding)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))
            }

            if isSavingOwnership {
                Text("Saving...")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.58))
            } else if let ownershipError {
                Text(ownershipError)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .cardStyle()
    }

    private var ownedToggleBinding: Binding<Bool> {
        Binding(
            get: { isOwnedToggle },
            set: { newValue in
                isOwnedToggle = newValue
                Task { await saveOwnershipChange() }
            }
        )
    }

    private var marketInsightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarketInsightView(
                snapshot: marketInsightSnapshot,
                isPremiumUnlocked: subscriptionManager.checkAccess(feature: .marketInsights),
                isLoading: isLoadingMarketInsights,
                onUnlock: {
                    showMarketInsightPaywall = true
                }
            )

            RentalMarketScaleView(
                currentRent: currentUnitRent,
                medianMarketRent: marketMedianUnitRent,
                daysOnMarket: marketInsightSnapshot?.daysOnMarket ?? 0,
                rentGrowthPercent: marketInsightSnapshot?.rentGrowthYoYPercent ?? 0,
                comparables: rentalMarketComparables,
                isPremiumUnlocked: subscriptionManager.checkAccess(feature: .marketInsights),
                onUnlock: { showMarketInsightPaywall = true }
            )

            if let marketInsightError, subscriptionManager.checkAccess(feature: .marketInsights) {
                Text(marketInsightError)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var pillarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("4 Pillars")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)

                Text("Tap any pillar for proof and assumptions.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.62))
            }

            if let evaluation = pillarEvaluation {
                PillarHeroRowView(evaluation: evaluation) { selected in
                    selectedPillarResult = selected
                }
            } else {
                Text("Add financing inputs to evaluate the pillars.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var mortgageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let breakdown = mortgageBreakdown {
                MortgageHeroCardView(
                    breakdown: breakdown,
                    termSelection: $termOverride,
                    defaultTerm: activeProperty.loanTermYears ?? 30
                ) {
                    showingMortgageDetails = true
                }
            } else {
                Text("Add purchase price, rate, down payment, taxes, insurance, and loan term.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var taxAssumptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Assumptions")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Used for the Tax Incentives pillar.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 52, height: 5)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                LabeledTextField(title: "Marginal Tax Rate %", text: $marginalTaxRateInput, keyboard: .decimalPad)
                    .onChange(of: marginalTaxRateInput) { _, newValue in
                        marginalTaxRateInput = InputFormatters.sanitizeDecimal(newValue)
                        taxAssumptionError = nil
                    }

                LabeledTextField(title: "Land Value %", text: $landValuePercentInput, keyboard: .decimalPad)
                    .onChange(of: landValuePercentInput) { _, newValue in
                        landValuePercentInput = InputFormatters.sanitizeDecimal(newValue)
                        taxAssumptionError = nil
                    }
            }

            if let taxAssumptionError {
                Text(taxAssumptionError)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(.red)
            }

            Button(isSavingTaxAssumptions ? "Saving..." : "Save Tax Assumptions") {
                Task { await saveTaxAssumptions() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSavingTaxAssumptions)
        }
        .cardStyle()
    }

    private var cashToCloseSection: some View {
        Button {
            showingCashToCloseLab = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cash to Close")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        Text("Upfront capital needed. Tap to run scenarios.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.richBlack.opacity(0.62))
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow)
                            .frame(width: 52, height: 5)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Lab")
                            .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.65))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow.opacity(0.35))
                    )
                }

                if let cashToClose = cashToCloseBreakdown {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            summaryTileContent(
                                title: "Down Payment",
                                value: Formatters.currency.string(from: NSNumber(value: cashToClose.downPayment)) ?? "$0",
                                showsInfo: false
                            )
                            summaryTileContent(
                                title: "Closing Costs",
                                value: Formatters.currency.string(from: NSNumber(value: cashToClose.closingCosts)) ?? "$0",
                                showsInfo: false
                            )
                        }
                        HStack(spacing: 10) {
                            summaryTileContent(
                                title: "Reno Reserve",
                                value: Formatters.currency.string(from: NSNumber(value: cashToClose.renoReserve)) ?? "$0",
                                showsInfo: false
                            )
                            summaryTileContent(
                                title: "Total Cash Needed",
                                value: Formatters.currency.string(from: NSNumber(value: cashToClose.total)) ?? "$0",
                                showsInfo: false
                            )
                        }
                    }

                    Text("Closing cost estimate uses \(String(format: "%.2f", defaultClosingCostRate))% of purchase price.")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.58))
                } else {
                    Text("Add down payment % to calculate cash to close.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
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
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 52, height: 5)
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

            scenarioImpactView(
                title: "Rent Roll Impact",
                scenarioProperty: inlineRentDraftProperty,
                emptyText: "Enter rent in at least one unit to preview grade impact."
            )

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
            HStack {
                Text("Operating Expenses")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                if !isEditingAnalysis {
                    Button(isEditingExpenses ? "Cancel" : "Edit") {
                        if isEditingExpenses {
                            isEditingExpenses = false
                            expenseSaveError = nil
                        } else {
                            beginExpenseEdit()
                        }
                    }
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                }
            }

            if isEditingExpenses {
                ExpenseModuleView(
                    module: expenseModule,
                    annualCashFlow: expenseScenarioEvaluation.metrics?.annualCashFlow,
                    mode: $expenseMode,
                    simpleRate: $simpleExpenseRate,
                    annualTaxes: $annualTaxes,
                    annualInsurance: $annualInsurance,
                    managementFee: $managementFee,
                    maintenanceReserves: $maintenanceReserves
                )

                scenarioImpactView(
                    title: "Expense Impact",
                    scenarioProperty: expenseDraftProperty,
                    emptyText: "Edit expense inputs to preview score impact."
                )

                if let expenseSaveError {
                    Text(expenseSaveError)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                }

                Button(isSavingExpenses ? "Saving..." : "Save Expenses") {
                    Task { await saveExpenseChanges() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSavingExpenses)
            } else {
                VStack(spacing: 10) {
                    if activeProperty.useStandardOperatingExpense ?? true {
                        let rate = activeProperty.operatingExpenseRate ?? standardOperatingExpenseRate
                        MetricRow(title: "Simple Mode", value: "Blended \(String(format: "%.2f%%", rate))")
                    } else if let expenses = activeProperty.operatingExpenses, !expenses.isEmpty {
                        MetricRow(title: "Detailed Mode", value: "Line-item expenses")
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
            }
        }
        .cardStyle()
    }
    private var photoChip: some View {
        let needsPhoto = activeProperty.imageURL.isEmpty
        return Button {
            showPhotoSourcePopover = true
        } label: {
            HStack(spacing: 6) {
                if isUploadingImage {
                    ProgressView()
                        .tint(Color.primaryYellow)
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: needsPhoto ? "plus.circle.fill" : "photo.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                Text(needsPhoto ? "Add Photo" : "Update Photo")
                    .font(.system(.caption, design: .rounded).weight(.bold))
            }
            .foregroundStyle(needsPhoto ? Color.richBlack : Color.richBlack.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(needsPhoto ? Color.primaryYellow.opacity(0.30) : Color.softGray)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(needsPhoto ? Color.primaryYellow.opacity(0.9) : Color.richBlack.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: needsPhoto ? Color.primaryYellow.opacity(0.30) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Update property photo")
        .popover(isPresented: $showPhotoSourcePopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    showPhotoSourcePopover = false
                    showPhotoLibraryPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    showPhotoSourcePopover = false
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCamera = true
                    } else {
                        photoUploadError = "Camera is unavailable on this device."
                    }
                } label: {
                    Label("Camera", systemImage: "camera")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            .padding(12)
            .frame(width: 180)
            .presentationCompactAdaptation(.none)
        }
    }

    private var mapChip: some View {
        Button {
            openInMaps()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Map")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.softGray)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open in Apple Maps")
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
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 52, height: 5)
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
                summaryMetricsRows(metrics)
            } else {
                Text("Add financing inputs to show NOI, cash flow, cap rate, cash-on-cash, and DCR.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private var sortedScenarios: [PropertyScenario] {
        scenarioCompareStore.sortedScenarios(by: scenarioSort)
    }

    private var scenarioCompareSection: some View {
        ScenarioCompareCardView(
            isPremium: subscriptionManager.isPremium,
            isExpanded: isScenarioCompareExpanded,
            isLoading: scenarioCompareStore.isLoading || isSavingScenario,
            errorMessage: scenarioActionError ?? scenarioCompareStore.errorMessage,
            scenarios: sortedScenarios,
            sortOption: scenarioSort,
            onToggleExpanded: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScenarioCompareExpanded.toggle()
                }
            },
            onChangeSort: { scenarioSort = $0 },
            onSaveCurrent: {
                scenarioActionError = nil
                guard scenarioCompareStore.canSaveScenario(isPremium: subscriptionManager.isPremium) else {
                    scenarioActionError = subscriptionManager.isPremium
                    ? "You can save up to 10 scenarios on Pro."
                    : "Free tier allows 1 scenario. Upgrade to Pro for up to 10."
                    if !subscriptionManager.isPremium {
                        AnalyticsTracker.track(.scenarioLimitHitFree, metadata: ["property_id": activeProperty.id ?? "unknown"])
                        AnalyticsTracker.track(.paywallOpenedFromScenarioCompare, metadata: ["property_id": activeProperty.id ?? "unknown"])
                        didOpenPaywallFromScenario = true
                        showMarketInsightPaywall = true
                    }
                    return
                }
                pendingScenarioDefaultName = "Scenario \(scenarioCompareStore.scenarios.count + 1)"
                showScenarioNameSheet = true
            },
            onUnlock: {
                AnalyticsTracker.track(.paywallOpenedFromScenarioCompare, metadata: ["property_id": activeProperty.id ?? "unknown"])
                didOpenPaywallFromScenario = true
                showMarketInsightPaywall = true
            },
            onApplyScenario: { scenario in
                applyScenario(scenario)
                AnalyticsTracker.track(.scenarioApplied, metadata: [
                    "property_id": activeProperty.id ?? "unknown",
                    "scenario_id": scenario.id
                ])
            },
            onDeleteScenario: { scenario in
                scenarioToDelete = scenario
            }
        )
    }

    private var maximumAllowableOfferSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maximum Allowable Offer")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("MAO = ARV - Rehab - Fixed - Selling - Desired Profit")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                    Capsule(style: .continuous)
                        .fill(Color.primaryYellow)
                        .frame(width: 52, height: 5)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                summaryTileContent(
                    title: "MAO",
                    value: Formatters.currency.string(from: NSNumber(value: maximumAllowableOfferValue)) ?? "$0",
                    showsInfo: false
                )
                summaryMetricButton(
                    title: "ARV",
                    value: Formatters.currency.string(from: NSNumber(value: maximumAllowableOfferARV)) ?? "$0",
                    info: .arv
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Desired Profit")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Text("\(Int(maoDesiredProfitPercent))%")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
                }

                Slider(value: $maoDesiredProfitPercent, in: 5...30, step: 1)
                    .tint(Color.primaryYellow)

                Text(Formatters.currency.string(from: NSNumber(value: maximumAllowableDesiredProfit)) ?? "$0")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.66))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fixed Costs")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Text("\(Int(maoFixedCostPercent))%")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
                }

                Slider(value: $maoFixedCostPercent, in: 0...12, step: 0.5)
                    .tint(Color.primaryYellow)

                Text(Formatters.currency.string(from: NSNumber(value: maximumAllowableFixedCosts)) ?? "$0")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.66))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Selling Costs")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Text("\(Int(maoSellingCostPercent))%")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
                }

                Slider(value: $maoSellingCostPercent, in: 0...15, step: 0.5)
                    .tint(Color.primaryYellow)

                Text(Formatters.currency.string(from: NSNumber(value: maximumAllowableSellingCosts)) ?? "$0")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.66))
            }

            VStack(spacing: 8) {
                maoBreakdownRow(title: "Rehab Costs", amount: maximumAllowableRehabCosts)
                maoBreakdownRow(title: "Fixed Costs", amount: maximumAllowableFixedCosts)
                maoBreakdownRow(title: "Selling Costs", amount: maximumAllowableSellingCosts)
            }
        }
        .cardStyle()
    }

    private func maoBreakdownRow(title: String, amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.62))
            Spacer()
            Text("-\(Formatters.currency.string(from: NSNumber(value: amount)) ?? "$0")")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack.opacity(0.82))
        }
    }

    private func summaryTileContent(title: String, value: String, showsInfo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                if showsInfo {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                }
            }
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

    private func summaryMetricsRows(_ metrics: DealMetrics) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryMetricButton(
                    title: "NOI",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0",
                    info: .netOperatingIncome
                )
                summaryMetricButton(
                    title: "Monthly Cash Flow",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow / 12.0)) ?? "$0",
                    info: .cashFlow
                )
            }

            HStack(spacing: 12) {
                summaryTileContent(
                    title: "Annual Cash Flow",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow)) ?? "$0",
                    showsInfo: false
                )
                summaryMetricButton(
                    title: "Cap Rate",
                    value: Formatters.percent.string(from: NSNumber(value: metrics.capRate)) ?? "0%",
                    info: .capRate
                )
            }

            HStack(spacing: 12) {
                summaryMetricButton(
                    title: "Cash-on-Cash",
                    value: Formatters.percent.string(from: NSNumber(value: metrics.cashOnCash)) ?? "0%",
                    info: .cashOnCash
                )
                summaryMetricButton(
                    title: "DCR",
                    value: String(format: "%.2f", metrics.debtCoverageRatio),
                    info: .dcr
                )
            }
        }
    }

    private func summaryMetricButton(title: String, value: String, info: MetricInfoType) -> some View {
        Button {
            infoMetric = info
        } label: {
            summaryTileContent(title: title, value: value, showsInfo: true)
        }
        .buttonStyle(.plain)
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
                checklistRow(
                    "Add rent roll",
                    complete: hasCompletedRentRoll(for: activeProperty),
                    destinationHint: "Update in Rent Roll section"
                )
                checklistRow(
                    "Add capex/reno",
                    complete: hasCapexData(for: activeProperty),
                    destinationHint: "Update in Cash to Close Lab or Analysis Lab"
                )
                checklistRow(
                    "Review expenses",
                    complete: hasReviewedExpenses(for: activeProperty),
                    destinationHint: "Update in Operating Expenses section"
                )
            }

            Text("Use the labeled sections below to complete each missing input.")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.62))
        }
        .cardStyle()
    }

    private var shouldShowCompleteAnalysisSection: Bool {
        !missingAnalysisInputs(for: activeProperty).isEmpty
    }

    private func checklistRow(_ title: String, complete: Bool, destinationHint: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(complete ? Color.primaryYellow : Color.richBlack.opacity(0.35))
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(complete ? 1 : 0.65))
                Spacer()
            }

            if !complete {
                Text(destinationHint)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.52))
                    .padding(.leading, 26)
            }
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
                    ForEach(Array(gradeProfileStore.profiles.enumerated()), id: \.offset) { _, profile in
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

    private func exportPDF() async {
        exportError = nil
        isExporting = true

        guard let metrics = analysisMetrics else {
            exportError = "Add financing inputs to export the report."
            isExporting = false
            return
        }

        let image = await ImageLoader.loadImage(from: activeProperty.imageURL, maxPixelSize: 1600)

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

        let appreciation = liveDisplayProperty.appreciationRate ?? 0
        return EvaluatorEngine.evaluate(
            purchasePrice: liveDisplayProperty.purchasePrice,
            annualCashFlow: metrics.annualCashFlow,
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: appreciation,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            marginalTaxRate: liveDisplayProperty.marginalTaxRate,
            landValuePercent: liveDisplayProperty.landValuePercent
        )
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

    private func beginExpenseEdit() {
        let source = activeProperty
        let isStandard = source.useStandardOperatingExpense ?? true
        expenseMode = isStandard ? .simple : .detailed
        simpleExpenseRate = String(format: "%.2f", source.operatingExpenseRate ?? standardOperatingExpenseRate)
        annualTaxes = source.annualTaxes.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? ""
        annualInsurance = source.annualInsurance.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? ""
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
        expenseSaveError = nil
        isEditingExpenses = true
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

    private func syncTaxAssumptionsInputs(from property: Property) {
        marginalTaxRateInput = property.marginalTaxRate.map { String(format: "%.2f", $0) } ?? ""
        landValuePercentInput = property.landValuePercent.map { String(format: "%.2f", $0) } ?? ""
        taxAssumptionError = nil
    }

    private func syncBasicInputs(from property: Property) {
        address = property.address
        city = property.city ?? ""
        state = property.state ?? ""
        zipCode = property.zipCode ?? ""
        purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: property.purchasePrice)) ?? String(property.purchasePrice)
        basicsSaveError = nil
    }

    private var shouldShowBasicAddressSuggestions: Bool {
        isPropertyBasicsExpanded
        && !isApplyingAddressSelection
        && subscriptionManager.checkAccess(feature: .autoFillAddress)
        && !locationSearchService.results.isEmpty
        && address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private var basicAutoFillAddressButton: some View {
        Button {
            if subscriptionManager.checkAccess(feature: .autoFillAddress) {
                let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
                if query.count >= 3 {
                    updateBasicAddressAutocompleteQuery(with: query)
                } else {
                    basicsSaveError = "Enter at least 3 address characters for Auto-Fill."
                }
            } else {
                showMarketInsightPaywall = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Auto-Fill Address")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                if !subscriptionManager.checkAccess(feature: .autoFillAddress) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                }
                Spacer()
            }
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var basicAddressSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(Array(locationSearchService.results.prefix(5).enumerated()), id: \.offset) { _, completion in
                Button {
                    applyBasicAddressCompletion(completion)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primaryYellow)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(completion.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                                .lineLimit(1)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle)
                                    .font(.system(.caption, design: .rounded).weight(.medium))
                                    .foregroundStyle(Color.richBlack.opacity(0.62))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if completion != locationSearchService.results.prefix(5).last {
                    Divider().opacity(0.22)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func updateBasicAddressAutocompleteQuery(with input: String) {
        guard subscriptionManager.checkAccess(feature: .autoFillAddress) else {
            locationSearchService.query = ""
            locationSearchService.results = []
            return
        }
        guard !isApplyingAddressSelection else { return }
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.count >= 3 {
            locationSearchService.query = query
        } else {
            locationSearchService.query = ""
            locationSearchService.results = []
        }
    }

    private func applyBasicAddressCompletion(_ completion: MKLocalSearchCompletion) {
        guard subscriptionManager.checkAccess(feature: .autoFillAddress) else {
            showMarketInsightPaywall = true
            return
        }
        Task { @MainActor in
            isApplyingAddressSelection = true
            defer { isApplyingAddressSelection = false }

            do {
                if let mapItem = try await locationSearchService.select(completion) {
                    applyPlacemarkToBasics(mapItem.placemark, fallbackAddress: completion.title)
                } else {
                    address = completion.title
                }
            } catch {
                address = completion.title
            }

            basicsSaveError = nil
            locationSearchService.query = ""
            locationSearchService.results = []
        }
    }

    private func applyPlacemarkToBasics(_ placemark: MKPlacemark, fallbackAddress: String) {
        let streetNumber = placemark.subThoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let streetName = placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let street = [streetNumber, streetName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        address = street.isEmpty ? fallbackAddress : street

        if let cityValue = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines), !cityValue.isEmpty {
            city = cityValue
        }

        if let stateValue = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines), !stateValue.isEmpty {
            state = String(stateValue.prefix(2)).uppercased()
        }

        if let postalCode = placemark.postalCode {
            let normalizedZip = String(postalCode.filter(\.isNumber).prefix(5))
            if !normalizedZip.isEmpty {
                zipCode = normalizedZip
            }
        }
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

    private func saveTaxAssumptions() async {
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            taxAssumptionError = "Property was not found. Reload and try again."
            return
        }

        isSavingTaxAssumptions = true
        defer { isSavingTaxAssumptions = false }
        taxAssumptionError = nil

        var updated = propertyStore.properties[index]
        updated.marginalTaxRate = Double(marginalTaxRateInput)
        updated.landValuePercent = Double(landValuePercentInput)

        do {
            try await propertyStore.updateProperty(updated)
        } catch {
            taxAssumptionError = error.localizedDescription
        }
    }

    private func saveOwnershipChange() async {
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            ownershipError = "Property was not found. Reload and try again."
            return
        }

        ownershipError = nil
        isSavingOwnership = true
        defer { isSavingOwnership = false }

        var updated = propertyStore.properties[index]
        updated.isOwned = isOwnedToggle

        do {
            try await propertyStore.updateProperty(updated)
        } catch {
            ownershipError = error.localizedDescription
        }
    }

    private func saveBasicDetails() async {
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            basicsSaveError = "Property was not found. Reload and try again."
            return
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            basicsSaveError = "Address is required."
            return
        }

        guard let parsedPurchasePrice = InputFormatters.parseCurrency(purchasePrice), parsedPurchasePrice > 0 else {
            basicsSaveError = "Enter a valid purchase price."
            return
        }

        basicsSaveError = nil
        isSavingBasics = true
        defer { isSavingBasics = false }

        var updated = propertyStore.properties[index]
        updated.address = trimmedAddress
        updated.city = city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.state = state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : state.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.zipCode = zipCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : zipCode.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.purchasePrice = parsedPurchasePrice

        do {
            try await propertyStore.updateProperty(updated)
            persistedPropertySnapshot = updated
            syncBasicInputs(from: updated)
        } catch {
            basicsSaveError = error.localizedDescription
        }
    }

    @MainActor
    private func loadMarketInsightsIfNeeded() async {
        marketInsightError = nil

        guard subscriptionManager.checkAccess(feature: .marketInsights) else {
            isLoadingMarketInsights = false
            rentAVMSnapshot = nil
            return
        }

        let addressLine = activeProperty.address.trimmingCharacters(in: .whitespacesAndNewlines)
        let cityLine = (activeProperty.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let stateLine = (activeProperty.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let zipLine = (activeProperty.zipCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fullAddress = [addressLine, cityLine, stateLine, zipLine]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        if !fullAddress.isEmpty {
            if let avm = try? await marketInsightsService.fetchLongTermRentAVM(fullAddress: fullAddress) {
                rentAVMSnapshot = avm
            }
        }

        guard let zip = activeProperty.zipCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !zip.isEmpty else {
            marketInsightSnapshot = nil
            isLoadingMarketInsights = false
            return
        }

        isLoadingMarketInsights = true
        defer { isLoadingMarketInsights = false }

        do {
            marketInsightSnapshot = try await marketInsightsService.fetchMarketInsights(
                zipCode: zip,
                city: activeProperty.city,
                state: activeProperty.state
            )
        } catch {
            marketInsightSnapshot = nil
            marketInsightError = userFriendlyMarketError(error)
        }
    }

    private func userFriendlyMarketError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("quota") || message.contains("credits") || message.contains("remaining credits") {
            return "Monthly insight credits reached. Upgrade or wait until next month to continue market scans."
        }
        if message.contains("unauthorized") || message.contains("invalid auth") {
            return "Please sign in again to load market insights."
        }
        return error.localizedDescription
    }

    private var currentUnitRent: Double {
        let monthlyRents = liveDisplayProperty.rentRoll.map(\.monthlyRent).filter { $0 > 0 }
        guard !monthlyRents.isEmpty else { return defaultMonthlyRentPerUnit }
        return monthlyRents.reduce(0, +) / Double(monthlyRents.count)
    }

    private var marketMedianUnitRent: Double {
        let avmRent = rentAVMSnapshot?.rent
        let suggested = avmRent ?? defaultMonthlyRentPerUnit
        return max(suggested, currentUnitRent * 0.9)
    }

    private var rentalMarketComparables: [RentalMarketScaleView.RentalComparable] {
        if let avmComps = rentAVMSnapshot?.comparables, !avmComps.isEmpty {
            return avmComps.prefix(8).map {
                RentalMarketScaleView.RentalComparable(
                    address: $0.address,
                    monthlyRent: $0.monthlyRent,
                    distanceMiles: $0.distanceMiles
                )
            }
        }

        let cityText = activeProperty.city ?? "Local"
        let stateText = activeProperty.state ?? "TX"
        let base = marketMedianUnitRent
        return [
            .init(address: "118 Amber Ln, \(cityText), \(stateText)", monthlyRent: base * 0.93, distanceMiles: 0.6),
            .init(address: "240 Ridge Rd, \(cityText), \(stateText)", monthlyRent: base * 1.00, distanceMiles: 1.1),
            .init(address: "75 Willow Dr, \(cityText), \(stateText)", monthlyRent: base * 1.06, distanceMiles: 1.8),
            .init(address: "9 Pine Crest Ct, \(cityText), \(stateText)", monthlyRent: base * 1.10, distanceMiles: 2.4)
        ]
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

    private var expenseDraftProperty: Property {
        var property = activeProperty
        property.useStandardOperatingExpense = expenseMode == .simple
        property.operatingExpenseRate = Double(simpleExpenseRate) ?? standardOperatingExpenseRate
        property.operatingExpenses = expenseMode == .detailed ? [
            OperatingExpenseItem(name: "Management Fee", annualAmount: expenseModule?.effectiveManagementFee ?? 0),
            OperatingExpenseItem(name: "Maintenance Reserves", annualAmount: expenseModule?.effectiveMaintenanceReserves ?? 0)
        ] : []
        property.annualTaxes = InputFormatters.parseCurrency(annualTaxes) ?? property.annualTaxes
        property.annualInsurance = InputFormatters.parseCurrency(annualInsurance) ?? property.annualInsurance
        return property
    }

    private var inlineRentDraftProperty: Property? {
        let units = RentRollEditorView.validUnits(from: inlineRentRollInputs)
        guard !units.isEmpty else { return nil }
        var property = activeProperty
        property.rentRoll = units
        return property
    }

    private var expenseScenarioEvaluation: (metrics: DealMetrics?, grade: Grade) {
        evaluatedMetricsAndGrade(for: expenseDraftProperty)
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

        var property = persistedProperty
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

    private func saveExpenseChanges() async {
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            expenseSaveError = "Property not found. Reload and try again."
            return
        }

        isSavingExpenses = true
        defer { isSavingExpenses = false }

        var updated = propertyStore.properties[index]
        updated.useStandardOperatingExpense = expenseMode == .simple
        updated.operatingExpenseRate = Double(simpleExpenseRate) ?? standardOperatingExpenseRate
        updated.operatingExpenses = expenseMode == .detailed ? [
            OperatingExpenseItem(name: "Management Fee", annualAmount: expenseModule?.effectiveManagementFee ?? 0),
            OperatingExpenseItem(name: "Maintenance Reserves", annualAmount: expenseModule?.effectiveMaintenanceReserves ?? 0)
        ] : []
        updated.annualTaxes = InputFormatters.parseCurrency(annualTaxes)
        updated.annualInsurance = InputFormatters.parseCurrency(annualInsurance)
        updated.missingAnalysisInputs = missingAnalysisInputs(for: updated)
        updated.analysisCompleteness = analysisCompletenessState(for: updated).rawValue

        do {
            try await propertyStore.updateProperty(updated)
            isEditingExpenses = false
            expenseSaveError = nil
        } catch {
            expenseSaveError = error.localizedDescription
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

    private func openInMaps() {
        let target = fullAddress.isEmpty ? activeProperty.address : fullAddress
        guard let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func uploadDetailImage(_ image: UIImage) async {
        photoUploadError = nil
        isUploadingImage = true
        defer { isUploadingImage = false }

        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            photoUploadError = "Property not found. Reload and try again."
            return
        }

        do {
            let uploaded = try await ImageUploadService.uploadPropertyImage(image, propertyId: propertyId)
            var updated = propertyStore.properties[index]
            updated.imagePath = uploaded.path
            updated.imageURL = uploaded.signedURL.absoluteString
            try await propertyStore.updateProperty(updated)
        } catch {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("not authenticated") {
                photoUploadError = "Please sign in again, then upload the photo."
            } else if message.localizedCaseInsensitiveContains("row-level security")
                || message.localizedCaseInsensitiveContains("permission")
                || message.localizedCaseInsensitiveContains("unauthorized") {
                photoUploadError = "Upload was blocked by Supabase storage policy. Re-apply the storage policies and retry."
            } else {
                photoUploadError = message
            }
        }
    }

    private var fullAddress: String {
        [activeProperty.address, activeProperty.city, activeProperty.state, activeProperty.zipCode]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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
        let isSimpleMode = property.useStandardOperatingExpense ?? true
        if !isSimpleMode { return true } // detailed mode explicitly reviewed

        let hasSimpleRate = (property.operatingExpenseRate ?? 0) > 0
        let hasTaxes = (property.annualTaxes ?? 0) > 0 || (property.annualTaxesInsurance ?? 0) > 0
        let hasInsurance = (property.annualInsurance ?? 0) > 0
        return hasSimpleRate || hasTaxes || hasInsurance
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
        return persistedProperty
    }

    private struct OfferDeadlineSummary {
        let label: String
        let isUrgent: Bool
    }

    private func nearestDeadlineSummary(for offer: PropertyOffer) -> OfferDeadlineSummary? {
        guard let revision = offerTrackerStore.currentRevision else { return nil }
        let baseDate = revision.createdAt ?? offer.createdAt ?? Date()

        var candidates: [(label: String, date: Date)] = []

        if let expiresAt = offer.expiresAt {
            candidates.append(("Expires", expiresAt))
        }
        if let estimatedCloseDate = revision.estimatedCloseDate {
            candidates.append(("Close", estimatedCloseDate))
        }
        if let optionDays = revision.optionPeriodDays {
            candidates.append(("Option", Calendar.current.date(byAdding: .day, value: optionDays, to: baseDate) ?? baseDate))
        }
        if let inspectionDays = revision.inspectionPeriodDays {
            candidates.append(("Inspect", Calendar.current.date(byAdding: .day, value: inspectionDays, to: baseDate) ?? baseDate))
        }
        if let financingDays = revision.financingContingencyDays {
            candidates.append(("Finance", Calendar.current.date(byAdding: .day, value: financingDays, to: baseDate) ?? baseDate))
        }

        guard let next = candidates
            .filter({ $0.date >= Date() })
            .sorted(by: { $0.date < $1.date })
            .first else { return nil }

        let isUrgent = next.date.timeIntervalSinceNow <= 60 * 60 * 48
        return OfferDeadlineSummary(label: next.label, isUrgent: isUrgent)
    }

    private var maximumAllowableOfferARV: Double {
        max(liveDisplayProperty.purchasePrice, 0)
    }

    private var maximumAllowableRehabCosts: Double {
        max(liveDisplayProperty.renoBudget ?? 0, 0)
    }

    private var maximumAllowableFixedCosts: Double {
        maximumAllowableOfferARV * (maoFixedCostPercent / 100.0)
    }

    private var maximumAllowableSellingCosts: Double {
        maximumAllowableOfferARV * (maoSellingCostPercent / 100.0)
    }

    private var maximumAllowableDesiredProfit: Double {
        maximumAllowableOfferARV * (maoDesiredProfitPercent / 100.0)
    }

    private var maximumAllowableOfferValue: Double {
        MFMetricEngine.maximumAllowableOffer(
            arv: maximumAllowableOfferARV,
            rehabCosts: maximumAllowableRehabCosts,
            fixedCosts: maximumAllowableFixedCosts,
            sellingCosts: maximumAllowableSellingCosts,
            desiredProfit: maximumAllowableDesiredProfit
        )
    }

    private var persistedProperty: Property {
        persistedPropertySnapshot ?? property
    }

    private func syncPersistedSnapshot() {
        guard let id = property.id else {
            persistedPropertySnapshot = property
            return
        }
        persistedPropertySnapshot = propertyStore.properties.first(where: { $0.id == id }) ?? property
    }

    private var liveDisplayProperty: Property {
        guard !isEditingAnalysis else { return activeProperty }
        var property = activeProperty
        let units = RentRollEditorView.validUnits(from: inlineRentRollInputs)
        if !units.isEmpty {
            property.rentRoll = units
        }
        property.marginalTaxRate = Double(marginalTaxRateInput)
        property.landValuePercent = Double(landValuePercentInput)
        return property
    }

    private var weightedGrade: Grade {
        weightedGrade(for: liveDisplayProperty)
    }

    private var activeProfile: GradeProfile {
        gradeProfileStore.effectiveProfile(for: activeProperty)
    }

    private func pillarSheetHeight(for result: PillarResult) -> CGFloat {
        var height: CGFloat = 300
        if result.pillar == .cashFlow {
            height += 64
        }
        if result.status == .needsInput {
            height += 34
        }
        height += min(CGFloat(result.detail.count) * 0.42, 130)
        return min(max(height, 300), 520)
    }

    private var profilePill: some View {
        Menu {
            Button("Default") { Task { await applyProfile(nil) } }
            ForEach(Array(gradeProfileStore.profiles.enumerated()), id: \.offset) { _, profile in
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

    private func bindScenarioStore() {
        guard let propertyId = activeProperty.id, !propertyId.isEmpty else { return }
        Task {
            await scenarioCompareStore.attach(propertyId: propertyId)
        }
        if hasTrackedScenarioOpenForPropertyId != propertyId {
            hasTrackedScenarioOpenForPropertyId = propertyId
            AnalyticsTracker.track(.scenarioCompareOpened, metadata: ["property_id": propertyId])
        }
    }

    private func bindOfferStore() {
        guard let propertyId = activeProperty.id, !propertyId.isEmpty else { return }
        Task {
            await offerTrackerStore.bind(propertyId: propertyId, isPremium: subscriptionManager.isPremium)
        }
    }

    private func saveScenario(named rawName: String) async {
        showScenarioNameSheet = false
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            scenarioActionError = "Scenario name is required."
            return
        }
        guard let propertyId = activeProperty.id, !propertyId.isEmpty else {
            scenarioActionError = "Property ID is missing."
            return
        }
        guard scenarioCompareStore.canSaveScenario(isPremium: subscriptionManager.isPremium) else {
            scenarioActionError = "Scenario limit reached."
            return
        }

        let snapshot = liveDisplayProperty
        let evaluation = evaluatedMetricsAndGrade(for: snapshot)
        guard let metrics = evaluation.metrics else {
            scenarioActionError = "Add financing and rent inputs before saving a scenario."
            return
        }

        isSavingScenario = true
        defer { isSavingScenario = false }
        scenarioActionError = nil

        let now = Date()
        let scenario = PropertyScenario(
            id: UUID().uuidString.lowercased(),
            propertyId: propertyId,
            userId: snapshot.userId ?? "",
            name: name,
            assumptions: PropertyScenarioAssumptions(
                purchasePrice: snapshot.purchasePrice,
                downPaymentPercent: snapshot.downPaymentPercent,
                interestRate: snapshot.interestRate,
                loanTermYears: snapshot.loanTermYears,
                annualTaxes: snapshot.annualTaxes,
                annualInsurance: snapshot.annualInsurance,
                useStandardOperatingExpense: snapshot.useStandardOperatingExpense,
                operatingExpenseRate: snapshot.operatingExpenseRate,
                operatingExpenses: snapshot.operatingExpenses,
                rentRoll: snapshot.rentRoll,
                capexItems: snapshot.capexItems,
                renoBudget: snapshot.renoBudget,
                gradeProfileId: snapshot.gradeProfileId
            ),
            computedMetrics: PropertyScenarioMetrics(
                annualCashFlow: metrics.annualCashFlow,
                netOperatingIncome: metrics.netOperatingIncome,
                capRate: metrics.capRate,
                cashOnCash: metrics.cashOnCash,
                dcr: metrics.debtCoverageRatio
            ),
            grade: evaluation.grade.rawValue,
            createdAt: now,
            updatedAt: now
        )

        await scenarioCompareStore.saveScenario(scenario)
        if let latestError = scenarioCompareStore.errorMessage {
            scenarioActionError = latestError
            return
        }

        AnalyticsTracker.track(.scenarioSaved, metadata: [
            "property_id": propertyId,
            "scenario_id": scenario.id
        ])
    }

    private func deleteScenario(_ scenario: PropertyScenario) async {
        scenarioToDelete = nil
        guard let propertyId = activeProperty.id, !propertyId.isEmpty else {
            scenarioActionError = "Property ID is missing."
            return
        }

        scenarioActionError = nil
        await scenarioCompareStore.deleteScenario(id: scenario.id, propertyId: propertyId)
        if let latestError = scenarioCompareStore.errorMessage {
            scenarioActionError = latestError
            return
        }

        AnalyticsTracker.track(.scenarioDeleted, metadata: [
            "property_id": propertyId,
            "scenario_id": scenario.id
        ])
    }

    private func applyScenario(_ scenario: PropertyScenario) {
        let assumptions = scenario.assumptions
        isEditingAnalysis = true

        purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: assumptions.purchasePrice)) ?? "\(assumptions.purchasePrice)"
        downPaymentPercent = assumptions.downPaymentPercent.map { String(format: "%.2f", $0) } ?? ""
        interestRate = assumptions.interestRate.map { String(format: "%.3f", $0) } ?? ""
        loanTermYears = assumptions.loanTermYears ?? (activeProperty.loanTermYears ?? 30)
        annualTaxes = assumptions.annualTaxes.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""
        annualInsurance = assumptions.annualInsurance.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""
        selectedProfileId = assumptions.gradeProfileId
        renoBudget = assumptions.renoBudget.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""

        let mappedInputs = assumptions.rentRoll.isEmpty ? [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")] : assumptions.rentRoll.map {
            RentUnitInput(
                monthlyRent: Formatters.currencyTwo.string(from: NSNumber(value: $0.monthlyRent)) ?? "\($0.monthlyRent)",
                unitType: $0.unitType,
                bedrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bedrooms)) ?? String($0.bedrooms),
                bathrooms: Formatters.bedsBaths.string(from: NSNumber(value: $0.bathrooms)) ?? String($0.bathrooms),
                squareFeet: $0.squareFeet.map { String(Int($0)) } ?? ""
            )
        }
        rentRollInputs = mappedInputs
        inlineRentRollInputs = mappedInputs

        expenseMode = (assumptions.useStandardOperatingExpense ?? true) ? .simple : .detailed
        simpleExpenseRate = assumptions.operatingExpenseRate.map { String(format: "%.2f", $0) } ?? String(standardOperatingExpenseRate)
        if let expenses = assumptions.operatingExpenses {
            managementFee = expenses.first(where: { $0.name.localizedCaseInsensitiveContains("management") })
                .map { Formatters.currencyTwo.string(from: NSNumber(value: $0.annualAmount)) ?? "\($0.annualAmount)" } ?? ""
            maintenanceReserves = expenses.first(where: { $0.name.localizedCaseInsensitiveContains("maintenance") })
                .map { Formatters.currencyTwo.string(from: NSNumber(value: $0.annualAmount)) ?? "\($0.annualAmount)" } ?? ""
        } else {
            managementFee = ""
            maintenanceReserves = ""
        }

        capexInputs = (assumptions.capexItems ?? []).map {
            CapexItemInput(
                name: $0.name,
                amount: Formatters.currencyTwo.string(from: NSNumber(value: $0.annualAmount)) ?? "\($0.annualAmount)"
            )
        }
        if capexInputs.isEmpty {
            capexInputs = [CapexItemInput(name: "", amount: "")]
        }
    }

    private func applyMortgageScenario(_ scenario: MortgageScenarioValues) {
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            return
        }

        termOverride = scenario.termYears
        propertyStore.properties[index].downPaymentPercent = scenario.downPaymentPercent
        propertyStore.properties[index].interestRate = scenario.interestRate
        propertyStore.properties[index].annualTaxes = scenario.annualTaxes
        propertyStore.properties[index].annualInsurance = scenario.annualInsurance
        propertyStore.properties[index].loanTermYears = scenario.termYears
        let updated = propertyStore.properties[index]
        persistedPropertySnapshot = updated

        Task {
            do {
                try await propertyStore.updateProperty(updated)
            } catch { }
        }
    }

    private func applyCashToCloseScenario(_ scenario: CashToCloseScenarioValues) {
        defaultClosingCostRate = scenario.closingCostRate
        guard let propertyId = activeProperty.id,
              let index = propertyStore.properties.firstIndex(where: { $0.id == propertyId }) else {
            return
        }

        propertyStore.properties[index].downPaymentPercent = scenario.downPaymentPercent
        propertyStore.properties[index].renoBudget = scenario.renoReserve
        propertyStore.properties[index].analysisCompleteness = analysisCompletenessState(for: propertyStore.properties[index]).rawValue
        propertyStore.properties[index].missingAnalysisInputs = missingAnalysisInputs(for: propertyStore.properties[index])
        let updated = propertyStore.properties[index]
        persistedPropertySnapshot = updated
        renoBudget = Formatters.currencyTwo.string(from: NSNumber(value: scenario.renoReserve)) ?? "\(scenario.renoReserve)"

        Task {
            do {
                try await propertyStore.updateProperty(updated)
            } catch { }
        }
    }

    private func evaluateCashToCloseScenario(_ scenario: CashToCloseScenarioValues) -> (metrics: DealMetrics?, grade: Grade) {
        var scenarioProperty = activeProperty
        scenarioProperty.downPaymentPercent = scenario.downPaymentPercent
        scenarioProperty.renoBudget = scenario.renoReserve

        guard var metrics = MetricsEngine.computeMetrics(property: scenarioProperty) else {
            return (nil, .dOrF)
        }

        let downPaymentCash = max(scenarioProperty.purchasePrice * (scenario.downPaymentPercent / 100.0), 0)
        let closingCostCash = max(scenarioProperty.purchasePrice * (scenario.closingCostRate / 100.0), 0)
        let renoCash = max(scenario.renoReserve, 0)
        let totalCashToClose = max(downPaymentCash + closingCostCash + renoCash, 0.0001)

        let adjustedCoC = metrics.annualCashFlow / totalCashToClose
        metrics.cashOnCash = adjustedCoC
        metrics.grade = MetricsEngine.gradeFor(cashOnCash: adjustedCoC, dcr: metrics.debtCoverageRatio)

        let annualPrincipalPaydown: Double = {
            guard let down = scenarioProperty.downPaymentPercent,
                  let rate = scenarioProperty.interestRate,
                  let breakdown = MetricsEngine.mortgageBreakdown(
                    purchasePrice: scenarioProperty.purchasePrice,
                    downPaymentPercent: down,
                    interestRate: rate,
                    loanTermYears: Double(scenarioProperty.loanTermYears ?? 30),
                    annualTaxes: scenarioProperty.annualTaxes ?? (scenarioProperty.annualTaxesInsurance ?? 0),
                    annualInsurance: scenarioProperty.annualInsurance ?? 0
                  ) else {
                return 0
            }
            return breakdown.annualPrincipal
        }()

        let profile = gradeProfileStore.effectiveProfile(for: scenarioProperty)
        let grade = MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: scenarioProperty.purchasePrice,
            unitCount: max(scenarioProperty.rentRoll.count, 1),
            annualPrincipalPaydown: annualPrincipalPaydown,
            appreciationRate: scenarioProperty.appreciationRate ?? 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )

        return (metrics, grade)
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

    private var cashToCloseBreakdown: (downPayment: Double, closingCosts: Double, renoReserve: Double, total: Double)? {
        guard let downPaymentPercent = activeProperty.downPaymentPercent else { return nil }
        let purchasePrice = activeProperty.purchasePrice
        let downPayment = max(purchasePrice * (downPaymentPercent / 100.0), 0)
        let closingCosts = max(purchasePrice * (defaultClosingCostRate / 100.0), 0)
        let renoReserve = max(activeProperty.renoBudget ?? 0, 0)
        return (downPayment, closingCosts, renoReserve, downPayment + closingCosts + renoReserve)
    }

    private var totalBeds: Double {
        liveDisplayProperty.rentRoll.reduce(0) { $0 + $1.bedrooms }
    }

    private var totalBaths: Double {
        liveDisplayProperty.rentRoll.reduce(0) { $0 + $1.bathrooms }
    }

    private func weightedGrade(for property: Property) -> Grade {
        guard let metrics = MetricsEngine.computeMetrics(property: property),
              let downPayment = property.downPaymentPercent,
              let interestRate = property.interestRate,
              let breakdown = MetricsEngine.mortgageBreakdown(
                purchasePrice: property.purchasePrice,
                downPaymentPercent: downPayment,
                interestRate: interestRate,
                loanTermYears: Double(property.loanTermYears ?? 30),
                annualTaxes: property.annualTaxes ?? (property.annualTaxesInsurance ?? 0),
                annualInsurance: property.annualInsurance ?? 0
              ) else {
            return MetricsEngine.computeMetrics(property: property)?.grade ?? .dOrF
        }
        let profile = gradeProfileStore.effectiveProfile(for: property)
        return MetricsEngine.weightedGrade(
            metrics: metrics,
            purchasePrice: property.purchasePrice,
            unitCount: max(property.rentRoll.count, 1),
            annualPrincipalPaydown: breakdown.annualPrincipal,
            appreciationRate: property.appreciationRate ?? 0,
            cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
            profile: profile
        )
    }

    private func evaluatedMetricsAndGrade(for property: Property) -> (metrics: DealMetrics?, grade: Grade) {
        let metrics = MetricsEngine.computeMetrics(property: property)
        let grade = weightedGrade(for: property)
        return (metrics, grade)
    }

    @ViewBuilder
    private func scenarioImpactView(title: String, scenarioProperty: Property?, emptyText: String) -> some View {
        let baseline = evaluatedMetricsAndGrade(for: activeProperty)
        let scenario = scenarioProperty.map { evaluatedMetricsAndGrade(for: $0) }

        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack.opacity(0.62))

            if let scenario,
               let baselineMetrics = baseline.metrics,
               let scenarioMetrics = scenario.metrics {
                HStack(spacing: 10) {
                    gradePill(label: "Current", grade: baseline.grade)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.richBlack.opacity(0.45))
                    gradePill(label: "Scenario", grade: scenario.grade)
                    Spacer()
                    Text(gradeDeltaText(from: baseline.grade, to: scenario.grade))
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
                }

                HStack(spacing: 8) {
                    impactPill(title: "Cash Flow", value: signedCurrency((scenarioMetrics.annualCashFlow - baselineMetrics.annualCashFlow) / 12.0) + "/mo")
                    impactPill(title: "CoC", value: signedPercent(scenarioMetrics.cashOnCash - baselineMetrics.cashOnCash))
                    impactPill(title: "DCR", value: signedDecimal(scenarioMetrics.debtCoverageRatio - baselineMetrics.debtCoverageRatio))
                }
            } else {
                Text(emptyText)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.55))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func gradePill(label: String, grade: Grade) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.58))
            Text(grade.rawValue)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(gradeAccent(for: grade).opacity(0.2))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(gradeAccent(for: grade).opacity(0.55), lineWidth: 1)
        )
    }

    private func impactPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func gradeAccent(for grade: Grade) -> Color {
        switch grade {
        case .a: return Color.primaryYellow
        case .b: return Color.green.opacity(0.75)
        case .c: return Color.orange.opacity(0.8)
        case .dOrF: return Color.red.opacity(0.75)
        }
    }

    private func gradeDeltaText(from baseline: Grade, to scenario: Grade) -> String {
        let tiers: [Grade: Int] = [.a: 3, .b: 2, .c: 1, .dOrF: 0]
        let delta = (tiers[scenario] ?? 0) - (tiers[baseline] ?? 0)
        if delta == 0 { return "No grade change" }
        return delta > 0 ? "+\(delta) tier" : "\(delta) tier"
    }

    private func signedPercent(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f%%", abs(value) * 100.0))"
    }

    private func signedCurrency(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        let amount = Formatters.currency.string(from: NSNumber(value: abs(value))) ?? "$0"
        return "\(sign)\(amount)"
    }

    private func signedDecimal(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.2f", abs(value)))"
    }

    private var effectiveUnitCount: Int {
        let parsedHints = liveDisplayProperty.rentRoll.compactMap { unitCountHint(from: $0.unitType) }
        let hintCount = parsedHints.max() ?? 0
        return max(liveDisplayProperty.rentRoll.count, hintCount, 1)
    }

    private func unitCountHint(from raw: String) -> Int? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }

        if text.contains("single") { return 1 }
        if text.contains("duplex") { return 2 }
        if text.contains("triplex") { return 3 }
        if text.contains("quad") || text.contains("fourplex") { return 4 }
        if text.contains("10+") { return 10 }
        if text.contains("5-10") { return 5 }

        if let match = text.range(of: #"\d+"#, options: .regularExpression) {
            return Int(text[match])
        }

        return nil
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func openDealRoom() {
        guard let propertyId = activeProperty.id else { return }
        collaborationFocusPropertyId = propertyId
        dashboardSelectedTab = 1
        dismiss()
    }
}

private extension View {
    func erasedToAnyView() -> AnyView {
        AnyView(self)
    }
}

private struct CapexItemInput: Identifiable {
    let id = UUID()
    var name: String
    var amount: String
}

private struct SummaryMetricsGrid: View {
    let metrics: DealMetrics
    let onTapInfo: (MetricInfoType) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricTile(
                    title: "NOI",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.netOperatingIncome)) ?? "$0",
                    info: .netOperatingIncome
                )
                metricTile(
                    title: "Monthly Cash Flow",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow / 12.0)) ?? "$0",
                    info: .cashFlow
                )
            }

            HStack(spacing: 12) {
                staticTile(
                    title: "Annual Cash Flow",
                    value: Formatters.currency.string(from: NSNumber(value: metrics.annualCashFlow)) ?? "$0"
                )
                metricTile(
                    title: "Cap Rate",
                    value: Formatters.percent.string(from: NSNumber(value: metrics.capRate)) ?? "0%",
                    info: .capRate
                )
            }

            HStack(spacing: 12) {
                metricTile(
                    title: "Cash-on-Cash",
                    value: Formatters.percent.string(from: NSNumber(value: metrics.cashOnCash)) ?? "0%",
                    info: .cashOnCash
                )
                metricTile(
                    title: "DCR",
                    value: String(format: "%.2f", metrics.debtCoverageRatio),
                    info: .dcr
                )
            }
        }
    }

    private func metricTile(title: String, value: String, info: MetricInfoType) -> some View {
        Button {
            onTapInfo(info)
        } label: {
            tileContent(title: title, value: value, showsInfo: true)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows metric definition")
    }

    private func staticTile(title: String, value: String) -> some View {
        tileContent(title: title, value: value, showsInfo: false)
    }

    private func tileContent(title: String, value: String, showsInfo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                if showsInfo {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                }
            }
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
}

private struct PropertyCommandHeaderView: View {
    let address: String
    let grade: Grade
    let monthlyCashFlow: Double
    let profileName: String
    let profileColorHex: String
    let unitCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(address)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                    .lineLimit(2)

                Text("Monthly Cash Flow \(Formatters.currency.string(from: NSNumber(value: monthlyCashFlow)) ?? "$0")")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(monthlyCashFlow >= 0 ? Color.green.opacity(0.9) : Color.red.opacity(0.9))

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: profileColorHex))
                            .frame(width: 7, height: 7)
                        Text(profileName)
                            .lineLimit(1)
                    }
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.richBlack.opacity(0.65))
                    )

                    UnitTypeBadge(unitCount: unitCount)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primaryYellow.opacity(0.22))
                    .frame(width: 52, height: 52)
                    .blur(radius: 8)
                GradeCircleView(grade: grade)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.cardSurface.opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primaryYellow.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
    }
}

private struct DealToolChipModel: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let badgeText: String?
    let isEmphasized: Bool
    let isLocked: Bool
    let action: () -> Void
}

private struct DealToolChipStrip: View {
    let chips: [DealToolChipModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(chips) { chip in
                    DealToolChip(chip: chip)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}

private struct DealToolChip: View {
    let chip: DealToolChipModel

    var body: some View {
        Button(action: chip.action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconBadgeFill)
                            .frame(width: 28, height: 28)

                        Image(systemName: chip.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(iconForeground)
                    }

                    Text(chip.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if chip.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.richBlack.opacity(0.68))
                    } else if chip.isEmphasized {
                        Circle()
                            .fill((chip.statusColor ?? Color.primaryYellow).opacity(0.95))
                            .frame(width: 7, height: 7)
                            .shadow(color: (chip.statusColor ?? Color.primaryYellow).opacity(0.45), radius: 6, x: 0, y: 0)
                    }
                }

                HStack(spacing: 8) {
                    if let subtitle = chip.subtitle, !subtitle.isEmpty {
                        HStack(spacing: 6) {
                            if let statusColor = chip.statusColor {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                            }

                            Text(subtitle)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.72))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if let badgeText = chip.badgeText, !badgeText.isEmpty {
                        Text(badgeText)
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeFill)
                            )
                    }
                }
            }
            .frame(minWidth: 118, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(chip.isEmphasized ? Color.cardSurface.opacity(0.98) : Color.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor, lineWidth: chip.isEmphasized ? 1.25 : 1)
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (chip.statusColor ?? Color.primaryYellow).opacity(chip.isEmphasized ? 0.18 : 0.08),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: shadowColor, radius: chip.isEmphasized ? 14 : 8, x: 0, y: chip.isEmphasized ? 8 : 4)
            )
        }
        .buttonStyle(.plain)
    }

    private var borderColor: Color {
        if chip.isEmphasized {
            return (chip.statusColor ?? Color.primaryYellow).opacity(0.42)
        }
        return Color.richBlack.opacity(0.08)
    }

    private var shadowColor: Color {
        if chip.isEmphasized {
            return (chip.statusColor ?? Color.primaryYellow).opacity(0.2)
        }
        return Color.black.opacity(0.08)
    }

    private var iconBadgeFill: Color {
        if chip.isEmphasized {
            return (chip.statusColor ?? Color.primaryYellow).opacity(0.18)
        }
        return Color.softGray
    }

    private var iconForeground: Color {
        chip.statusColor ?? (chip.isEmphasized ? Color.primaryYellow : Color.richBlack)
    }

    private var badgeFill: Color {
        if chip.isLocked {
            return Color.softGray
        }
        return (chip.statusColor ?? Color.primaryYellow).opacity(chip.isEmphasized ? 0.22 : 0.14)
    }

    private var badgeForeground: Color {
        chip.isLocked ? Color.richBlack.opacity(0.7) : (chip.statusColor ?? Color.richBlack)
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
    .environmentObject(SubscriptionManager())
}
