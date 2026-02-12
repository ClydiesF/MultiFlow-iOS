import SwiftUI
import PhotosUI

struct EditPropertySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var propertyStore: PropertyStore
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @AppStorage("standardOperatingExpenseRate") private var standardOperatingExpenseRate = 35.0

    let property: Property

    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zipCode = ""
    @State private var imageURL = ""
    @State private var imagePath: String?
    @State private var purchasePrice = ""
    @State private var downPaymentPercent = ""
    @State private var interestRate = ""
    @State private var annualTaxes = ""
    @State private var annualInsurance = ""
    @State private var loanTermYears = 30
    @State private var rentRoll: [RentUnitInput] = []
    @State private var useStandardOperatingExpense = true
    @State private var operatingExpenseRate = ""
    @State private var operatingExpenses: [OperatingExpenseInput] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isUploadingImage = false
    @State private var imageError: String?
    @State private var selectedProfileId: String?

    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    LabeledTextField(title: "Address", text: $address, keyboard: .default)
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
                    LabeledTextField(title: "City", text: $city, keyboard: .default)
                    LabeledTextField(title: "State", text: $state, keyboard: .default)
                        .onChange(of: state) { _, newValue in
                            state = StateAbbreviationFormatter.abbreviate(newValue)
                        }
                    LabeledTextField(title: "ZIP Code", text: $zipCode, keyboard: .numberPad)
                    LabeledTextField(title: "Purchase Price", text: $purchasePrice, keyboard: .decimalPad)
                        .onChange(of: purchasePrice) { _, newValue in
                            purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                        }
                        .onSubmit {
                            if let value = InputFormatters.parseCurrency(purchasePrice) {
                                purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? purchasePrice
                            }
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

                    operatingExpenseSection

                    rentRollSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(isSaving ? "Saving..." : "Save Changes") {
                        Task { await saveChanges() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSaving)
                }
                .padding(24)
            }
            .navigationTitle("Edit Property")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { loadProperty() }
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
    }

    private var rentRollSection: some View {
        RentRollEditorView(
            units: $rentRoll,
            style: .full,
            allowsUnitType: true,
            requiresValidRentRow: true
        )
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

    @MainActor
    private func uploadImage(_ image: UIImage) async {
        imageError = nil
        isUploadingImage = true
        do {
            let uploaded = try await ImageUploadService.uploadPropertyImage(image, propertyId: property.id)
            imagePath = uploaded.path
            imageURL = uploaded.signedURL.absoluteString
        } catch {
            imageError = error.localizedDescription
        }
        isUploadingImage = false
    }

    private func loadProperty() {
        address = property.address
        city = property.city ?? ""
        state = property.state ?? ""
        zipCode = property.zipCode ?? ""
        imagePath = property.imagePath
        imageURL = property.imageURL
        purchasePrice = Formatters.currencyTwo.string(from: NSNumber(value: property.purchasePrice)) ?? String(property.purchasePrice)
        downPaymentPercent = property.downPaymentPercent.map { "\($0)" } ?? ""
        interestRate = property.interestRate.map { "\($0)" } ?? ""
        annualTaxes = property.annualTaxes.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? (property.annualTaxesInsurance.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? "")
        annualInsurance = property.annualInsurance.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? "\($0)" } ?? ""
        loanTermYears = property.loanTermYears ?? 30
        rentRoll = property.rentRoll.map {
            RentUnitInput(
                monthlyRent: Formatters.currencyTwo.string(from: NSNumber(value: $0.monthlyRent)) ?? String($0.monthlyRent),
                unitType: $0.unitType,
                bedrooms: String($0.bedrooms),
                bathrooms: String($0.bathrooms),
                squareFeet: $0.squareFeet.map { String(Int($0)) } ?? ""
            )
        }
        if rentRoll.isEmpty {
            rentRoll = [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "", squareFeet: "")]
        }
        useStandardOperatingExpense = property.useStandardOperatingExpense ?? true
        operatingExpenseRate = property.operatingExpenseRate.map { "\($0)" } ?? String(standardOperatingExpenseRate)
        operatingExpenses = property.operatingExpenses?.map {
            OperatingExpenseInput(name: $0.name, annualAmount: Formatters.currencyTwo.string(from: NSNumber(value: $0.annualAmount)) ?? String($0.annualAmount))
        } ?? [OperatingExpenseInput(name: "Repairs", annualAmount: "")]
        selectedProfileId = property.gradeProfileId ?? gradeProfileStore.defaultProfileId
    }

    private func saveChanges() async {
        errorMessage = nil
        guard let purchasePriceValue = InputFormatters.parseCurrency(purchasePrice),
              let taxesValue = InputFormatters.parseCurrency(annualTaxes),
              let insuranceValue = InputFormatters.parseCurrency(annualInsurance) else {
            errorMessage = "Enter a valid purchase price, taxes, and insurance."
            return
        }

        let rentUnits = RentRollEditorView.validUnits(from: rentRoll)
        if rentUnits.isEmpty {
            errorMessage = "Add at least one unit with monthly rent."
            return
        }

        let updated = Property(
            id: property.id,
            userId: property.userId,
            address: address,
            city: city.isEmpty ? nil : city,
            state: state.isEmpty ? nil : state,
            zipCode: zipCode.isEmpty ? nil : zipCode,
            imagePath: imagePath,
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
            let store = propertyStore
            try await store.updateProperty(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

}

#Preview {
    EditPropertySheet(property: Property(address: "123 Main", imageURL: "", purchasePrice: 450000, rentRoll: []))
        .environmentObject(PropertyStore())
        .environmentObject(GradeProfileStore())
}
