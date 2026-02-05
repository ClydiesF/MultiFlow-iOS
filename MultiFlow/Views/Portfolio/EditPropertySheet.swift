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
            let url = try await ImageUploadService.uploadPropertyImage(image, propertyId: property.id)
            imageURL = url.absoluteString
        } catch {
            imageError = "Unable to upload photo."
        }
        isUploadingImage = false
    }

    private func loadProperty() {
        address = property.address
        city = property.city ?? ""
        state = property.state ?? ""
        zipCode = property.zipCode ?? ""
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
                bathrooms: String($0.bathrooms)
            )
        }
        if rentRoll.isEmpty {
            rentRoll = [RentUnitInput(monthlyRent: "", unitType: "", bedrooms: "", bathrooms: "")]
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

        let rentUnits = rentRoll.compactMap { unit -> RentUnit? in
            guard let rentValue = InputFormatters.parseCurrency(unit.monthlyRent),
                  let beds = Double(unit.bedrooms),
                  let baths = Double(unit.bathrooms),
                  beds >= 0, baths >= 0 else { return nil }
            return RentUnit(id: unit.id.uuidString, monthlyRent: rentValue, unitType: unit.unitType, bedrooms: beds, bathrooms: baths)
        }

        if rentUnits.count != rentRoll.count {
            errorMessage = "Every unit must have bedrooms and bathrooms."
            return
        }

        let updated = Property(
            id: property.id,
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
            let store = propertyStore
            try await store.updateProperty(updated)
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
}

#Preview {
    EditPropertySheet(property: Property(address: "123 Main", imageURL: "", purchasePrice: 450000, rentRoll: []))
        .environmentObject(PropertyStore())
        .environmentObject(GradeProfileStore())
}
