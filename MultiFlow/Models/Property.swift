import Foundation

struct Property: Identifiable, Codable, Hashable {
    var id: String?
    var userId: String?
    var address: String
    var city: String?
    var state: String?
    var zipCode: String?
    var imagePath: String?
    var imageURL: String = ""
    var purchasePrice: Double
    var rentRoll: [RentUnit]
    var useStandardOperatingExpense: Bool?
    var operatingExpenseRate: Double?
    var operatingExpenses: [OperatingExpenseItem]?
    var annualTaxes: Double?
    var annualInsurance: Double?
    var annualTaxesInsurance: Double?
    var loanTermYears: Int?
    var downPaymentPercent: Double?
    var interestRate: Double?
    var appreciationRate: Double?
    var marginalTaxRate: Double?
    var landValuePercent: Double?
    var gradeProfileId: String?
    var suggestedOfferPrice: Double?

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
        case gradeProfileId = "grade_profile_id"
        case suggestedOfferPrice = "suggested_offer_price"
    }

    init(
        id: String? = nil,
        userId: String? = nil,
        address: String,
        city: String? = nil,
        state: String? = nil,
        zipCode: String? = nil,
        imagePath: String? = nil,
        imageURL: String = "",
        purchasePrice: Double,
        rentRoll: [RentUnit],
        useStandardOperatingExpense: Bool? = nil,
        operatingExpenseRate: Double? = nil,
        operatingExpenses: [OperatingExpenseItem]? = nil,
        annualTaxes: Double? = nil,
        annualInsurance: Double? = nil,
        annualTaxesInsurance: Double? = nil,
        loanTermYears: Int? = nil,
        downPaymentPercent: Double? = nil,
        interestRate: Double? = nil,
        appreciationRate: Double? = nil,
        marginalTaxRate: Double? = nil,
        landValuePercent: Double? = nil,
        gradeProfileId: String? = nil,
        suggestedOfferPrice: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.imagePath = imagePath
        self.imageURL = imageURL
        self.purchasePrice = purchasePrice
        self.rentRoll = rentRoll
        self.useStandardOperatingExpense = useStandardOperatingExpense
        self.operatingExpenseRate = operatingExpenseRate
        self.operatingExpenses = operatingExpenses
        self.annualTaxes = annualTaxes
        self.annualInsurance = annualInsurance
        self.annualTaxesInsurance = annualTaxesInsurance
        self.loanTermYears = loanTermYears
        self.downPaymentPercent = downPaymentPercent
        self.interestRate = interestRate
        self.appreciationRate = appreciationRate
        self.marginalTaxRate = marginalTaxRate
        self.landValuePercent = landValuePercent
        self.gradeProfileId = gradeProfileId
        self.suggestedOfferPrice = suggestedOfferPrice
    }
}
