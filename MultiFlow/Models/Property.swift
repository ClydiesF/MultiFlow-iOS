import Foundation
import FirebaseFirestore

struct Property: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var address: String
    var city: String?
    var state: String?
    var zipCode: String?
    var imageURL: String
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

    enum CodingKeys: String, CodingKey {
        case id
        case address = "Address"
        case city = "City"
        case state = "State"
        case zipCode = "ZipCode"
        case imageURL = "ImageURL"
        case purchasePrice = "PurchasePrice"
        case rentRoll = "RentRoll"
        case useStandardOperatingExpense = "UseStandardOperatingExpense"
        case operatingExpenseRate = "OperatingExpenseRate"
        case operatingExpenses = "OperatingExpenses"
        case annualTaxes = "AnnualTaxes"
        case annualInsurance = "AnnualInsurance"
        case annualTaxesInsurance = "AnnualTaxesInsurance"
        case loanTermYears = "LoanTermYears"
        case downPaymentPercent = "DownPaymentPercent"
        case interestRate = "InterestRate"
        case appreciationRate = "AppreciationRate"
        case marginalTaxRate = "MarginalTaxRate"
        case landValuePercent = "LandValuePercent"
        case gradeProfileId = "GradeProfileId"
    }

    init(
        id: String? = nil,
        address: String,
        city: String? = nil,
        state: String? = nil,
        zipCode: String? = nil,
        imageURL: String,
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
        gradeProfileId: String? = nil
    ) {
        self.id = id
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
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
    }
}
