import SwiftUI
import MapKit
import PhotosUI
internal import Combine

struct AddPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var didAddProperty: Bool
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0
    
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var imageURL = ""
    @State private var purchasePrice = ""
    @State private var useStandardOperatingExpense = true
    @State private var operatingExpenseRate = ""
    @State private var operatingExpenses: [OperatingExpenseInput] = [
        OperatingExpenseInput(name: "Repairs", annualAmount: "")
    ]
    @State private var downPaymentPercent = ""
    @State private var interestRate = ""
    @State private var annualTaxes = ""
    @State private var annualInsurance = ""
    @State private var loanTermYears = 30
    @State private var rentRoll: [RentUnitInput] = [
        RentUnitInput(monthlyRent: "", unitType: "1BR", bedrooms: "1", bathrooms: "1")
    ]
    @State private var errorMessage: String?
    @State private var isSaving = false
    @StateObject private var searchService = LocationSearchService()
    @State private var isSearching = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isUploadingImage = false
    @State private var imageError: String?
    @State private var selectedProfileId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                formBody
            }
            .navigationTitle("Add Property")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if operatingExpenseRate.isEmpty {
                operatingExpenseRate = String(standardOperatingExpenseRate)
            }
            if selectedProfileId == nil {
                selectedProfileId = gradeProfileStore.defaultProfileId
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
    }
    

    private var addressSuggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(searchService.results, id: \.self) { completion in
                Button {
                    Task { await handleSelection(completion) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(completion.title)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        Text(completion.subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.cardSurface)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private var mapSnapshotSection: some View {
        Button {
            // TODO: Implement snapshot regeneration if needed
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Color.softGray
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Map Snapshot")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text("Tap to regenerate")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
                Spacer()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.cardSurface)
            )
        }
        .buttonStyle(.plain)
    }

    private var formBody: some View {
        VStack(spacing: 20) {
            addressSection
            imageSection
            mapSnapshotSection
            locationSection
            pricingSection
            operatingExpenseSection
            rentRollSection
            errorSection
            saveButton
        }
        .padding(24)
    }
    private var addressSection: some View {
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

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Photo")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            ZStack {
                if let url = URL(string: imageURL), !imageURL.isEmpty {
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
                            .font(.system(size: 24, weight: .semibold))
                        Text("No photo yet")
                            .font(.system(.footnote, design: .rounded))
                    }
                    .foregroundStyle(Color.richBlack.opacity(0.6))
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                .buttonStyle(.bordered)

                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                .buttonStyle(.bordered)
            }

            if isUploadingImage {
                Text("Uploading photo...")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
            if let imageError {
                Text(imageError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
    }

    private var locationSection: some View {
        VStack(spacing: 12) {
            LabeledTextField(title: "City", text: $city, keyboard: .default)
            LabeledTextField(title: "State", text: $state, keyboard: .default)
                .onChange(of: state) { _, newValue in
                    state = StateAbbreviationFormatter.abbreviate(newValue)
                }
            LabeledTextField(title: "ZIP Code", text: $zipCode, keyboard: .numberPad)
        }
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            LabeledTextField(title: "Purchase Price", text: $purchasePrice, keyboard: .decimalPad)
                .onChange(of: purchasePrice) { _, newValue in
                    purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                }
                .onSubmit {
                    if let value = InputFormatters.parseCurrency(purchasePrice) {
                        purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? purchasePrice
                    }
                }
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
                    if let value = InputFormatters.parseCurrency(annualTaxes) {
                        annualTaxes = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? annualTaxes
                    }
                }
            LabeledTextField(title: "Annual Insurance", text: $annualInsurance, keyboard: .decimalPad)
                .onChange(of: annualInsurance) { _, newValue in
                    annualInsurance = InputFormatters.formatCurrencyLive(newValue)
                }
                .onSubmit {
                    if let value = InputFormatters.parseCurrency(annualInsurance) {
                        annualInsurance = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? annualInsurance
                    }
                }
            Picker("Loan Term", selection: $loanTermYears) {
                Text("15 years").tag(15)
                Text("20 years").tag(20)
                Text("30 years").tag(30)
            }
            .pickerStyle(.segmented)

            gradeProfilePicker
        }
    }

    private var gradeProfilePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    }

    private var errorSection: some View {
        Group {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var saveButton: some View {
        Button(isSaving ? "Saving..." : "Save Property") {
            Task { await saveProperty() }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSaving)
    }

    private var rentRollSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rent Roll")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
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
                            .onChange(of: unit.monthlyRent) { _, newValue in
                                unit.monthlyRent = InputFormatters.formatCurrencyLive(newValue)
                            }
                            .onSubmit {
                                if let value = InputFormatters.parseCurrency(unit.monthlyRent) {
                                    unit.monthlyRent = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? unit.monthlyRent
                                }
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


    private var operatingExpenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Operating Expenses")
                .font(.system(.headline, design: .rounded).weight(.semibold))
            
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
                                    expense.annualAmount = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? expense.annualAmount
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
                MetricRow(title: "Total Operating Expenses", value: Formatters.currencyTwo.string(from: NSNumber(value: total)) ?? "$0")
            }
        }
    }
    
    private func saveProperty() async {
        errorMessage = nil
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let taxesValue = InputFormatters.parseCurrency(annualTaxes),
              let insuranceValue = InputFormatters.parseCurrency(annualInsurance) else {
            errorMessage = "Enter a valid purchase price, taxes, and insurance."
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
            imageURL: imageURL,
            purchasePrice: purchasePriceValue,
            rentRoll: rentUnits,
            useStandardOperatingExpense: useStandardOperatingExpense,
            operatingExpenseRate: Double(operatingExpenseRate) ?? standardOperatingExpenseRate,
            operatingExpenses: operatingExpenses.compactMap { item in
                guard let amount = InputFormatters.parseCurrency(item.annualAmount) else { return nil }
                return OperatingExpenseItem(name: item.name, annualAmount: amount)
            },
            annualTaxes: taxesValue,
            annualInsurance: insuranceValue,
            loanTermYears: loanTermYears,
            downPaymentPercent: Double(downPaymentPercent),
            interestRate: Double(interestRate),
            gradeProfileId: selectedProfileId ?? gradeProfileStore.defaultProfileId
        )
        
        isSaving = true
        do {
            try await propertyStore.addProperty(property)
            didAddProperty = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
    
    private func missingBedsOrBaths(for unit: RentUnitInput) -> Bool {
        let beds = unit.bedrooms.trimmingCharacters(in: .whitespaces)
        let baths = unit.bathrooms.trimmingCharacters(in: .whitespaces)
        return beds.isEmpty || baths.isEmpty || Double(beds) == nil || Double(baths) == nil
    }
    
    @MainActor
    private func uploadImage(_ image: UIImage) async {
        imageError = nil
        isUploadingImage = true
        do {
            let url = try await ImageUploadService.uploadPropertyImage(image)
            imageURL = url.absoluteString
        } catch {
            imageError = error.localizedDescription
        }
        isUploadingImage = false
    }

    private func handleSelection(_ completion: MKLocalSearchCompletion) async {
        do {
            if let mapItem = try await searchService.select(completion) {
                let placemark = mapItem.placemark
                let street = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !street.isEmpty {
                    address = street
                } else if let title = placemark.title {
                    address = title.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? title
                } else {
                    address = mapItem.name ?? ""
                }
                city = placemark.locality ?? ""
                state = StateAbbreviationFormatter.abbreviate(placemark.administrativeArea ?? "")
                zipCode = placemark.postalCode ?? ""
            }
            isSearching = false
            searchService.results = []
        } catch {
            errorMessage = "Unable to fetch address details."
        }
    }
}


#if DEBUG

/// A lightweight preview-only store that mimics the API used by AddPropertySheet
/// without subclassing a potentially `final` type.
@MainActor
final class PreviewPropertyStore: ObservableObject {
    @Published var lastAddedProperty: Property?

    func addProperty(_ property: Property) async throws {
        // Simulate a tiny delay and capture the property for preview/testing
        try? await Task.sleep(nanoseconds: 50_000_000)
        lastAddedProperty = property
    }
}

#Preview {
    AddPropertySheet(didAddProperty: .constant(false))
        .environmentObject(PreviewPropertyStore())
        .environmentObject(GradeProfileStore())
}
#endif

