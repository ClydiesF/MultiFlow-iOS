import Foundation
import Supabase

final class SupabasePropertyRepository: PropertyRepositoryProtocol {
    private let client: SupabaseClient
    private let imageStorage: ImageStorageServiceProtocol
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(client: SupabaseClient, imageStorage: ImageStorageServiceProtocol) {
        self.client = client
        self.imageStorage = imageStorage
    }

    convenience init() {
        self.init(client: SupabaseManager.shared.client, imageStorage: SupabaseImageStorageService())
    }

    func fetchProperties(for userId: String) async throws -> [Property] {
        let rows: [PropertyDBRow] = try await client
            .from("properties")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value

        var items = rows.map { $0.toModel() }
        for index in items.indices {
            if let path = items[index].imagePath,
               let url = try? await imageStorage.signedURL(for: path) {
                items[index].imageURL = url.absoluteString
            }
        }
        return items
    }

    func addProperty(_ property: Property, userId: String) async throws {
        let row = PropertyDBRow(model: property, userId: userId)
        _ = try await client
            .from("properties")
            .insert(row)
            .execute()
    }

    func updateProperty(_ property: Property, userId: String) async throws {
        guard let id = property.id else { return }
        let row = PropertyDBRow(model: property, userId: userId)
        _ = try await client
            .from("properties")
            .update(row)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteProperty(id: String, userId: String) async throws {
        _ = try await client
            .from("properties")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws {
        await stopListening()

        let channel = client.channel("public:properties:\(userId)")
        self.channel = channel

        listenTask = Task {
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "properties",
                filter: "user_id=eq.\(userId)"
            )
            for await _ in changes {
                onChange()
            }
        }

        try await channel.subscribe()
    }

    func stopListening() async {
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            await client.removeChannel(channel)
            self.channel = nil
        }
    }
}

private struct PropertyDBRow: Codable {
    let id: String?
    let userId: String
    let address: String
    let city: String?
    let state: String?
    let zipCode: String?
    let imagePath: String?
    let purchasePrice: Double
    let rentRoll: [RentUnit]
    let useStandardOperatingExpense: Bool?
    let operatingExpenseRate: Double?
    let operatingExpenses: [OperatingExpenseItem]?
    let annualTaxes: Double?
    let annualInsurance: Double?
    let annualTaxesInsurance: Double?
    let loanTermYears: Int?
    let downPaymentPercent: Double?
    let interestRate: Double?
    let appreciationRate: Double?
    let marginalTaxRate: Double?
    let landValuePercent: Double?
    let isOwned: Bool?
    let gradeProfileId: String?
    let suggestedOfferPrice: Double?
    let analysisCompleteness: String?
    let missingAnalysisInputs: [String]?
    let capexItems: [OperatingExpenseItem]?
    let renoBudget: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case address
        case city
        case state
        case zipCode = "zip_code"
        case imagePath = "image_path"
        case purchasePrice = "purchase_price"
        case rentRoll = "rent_roll"
        case useStandardOperatingExpense = "use_standard_operating_expense"
        case operatingExpenseRate = "operating_expense_rate"
        case operatingExpenses = "operating_expenses"
        case annualTaxes = "annual_taxes"
        case annualInsurance = "annual_insurance"
        case annualTaxesInsurance = "annual_taxes_insurance"
        case loanTermYears = "loan_term_years"
        case downPaymentPercent = "down_payment_percent"
        case interestRate = "interest_rate"
        case appreciationRate = "appreciation_rate"
        case marginalTaxRate = "marginal_tax_rate"
        case landValuePercent = "land_value_percent"
        case isOwned = "is_owned"
        case gradeProfileId = "grade_profile_id"
        case suggestedOfferPrice = "suggested_offer_price"
        case analysisCompleteness = "analysis_completeness"
        case missingAnalysisInputs = "missing_analysis_inputs"
        case capexItems = "capex_items"
        case renoBudget = "reno_budget"
    }

    init(model: Property, userId: String) {
        self.id = model.id
        self.userId = userId
        self.address = model.address
        self.city = model.city
        self.state = model.state
        self.zipCode = model.zipCode
        self.imagePath = model.imagePath
        self.purchasePrice = model.purchasePrice
        self.rentRoll = model.rentRoll
        self.useStandardOperatingExpense = model.useStandardOperatingExpense
        self.operatingExpenseRate = model.operatingExpenseRate
        self.operatingExpenses = model.operatingExpenses
        self.annualTaxes = model.annualTaxes
        self.annualInsurance = model.annualInsurance
        self.annualTaxesInsurance = model.annualTaxesInsurance
        self.loanTermYears = model.loanTermYears
        self.downPaymentPercent = model.downPaymentPercent
        self.interestRate = model.interestRate
        self.appreciationRate = model.appreciationRate
        self.marginalTaxRate = model.marginalTaxRate
        self.landValuePercent = model.landValuePercent
        self.isOwned = model.isOwned
        self.gradeProfileId = model.gradeProfileId
        self.suggestedOfferPrice = model.suggestedOfferPrice
        self.analysisCompleteness = model.analysisCompleteness
        self.missingAnalysisInputs = model.missingAnalysisInputs
        self.capexItems = model.capexItems
        self.renoBudget = model.renoBudget
    }

    func toModel() -> Property {
        Property(
            id: id,
            userId: userId,
            address: address,
            city: city,
            state: state,
            zipCode: zipCode,
            imagePath: imagePath,
            imageURL: "",
            purchasePrice: purchasePrice,
            rentRoll: rentRoll,
            useStandardOperatingExpense: useStandardOperatingExpense,
            operatingExpenseRate: operatingExpenseRate,
            operatingExpenses: operatingExpenses,
            annualTaxes: annualTaxes,
            annualInsurance: annualInsurance,
            annualTaxesInsurance: annualTaxesInsurance,
            loanTermYears: loanTermYears,
            downPaymentPercent: downPaymentPercent,
            interestRate: interestRate,
            appreciationRate: appreciationRate,
            marginalTaxRate: marginalTaxRate,
            landValuePercent: landValuePercent,
            isOwned: isOwned,
            gradeProfileId: gradeProfileId,
            suggestedOfferPrice: suggestedOfferPrice,
            analysisCompleteness: analysisCompleteness,
            missingAnalysisInputs: missingAnalysisInputs,
            capexItems: capexItems,
            renoBudget: renoBudget
        )
    }
}
