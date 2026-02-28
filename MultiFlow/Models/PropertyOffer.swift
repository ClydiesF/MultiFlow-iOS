import Foundation

struct PropertyOffer: Identifiable, Codable, Hashable {
    var id: String?
    var propertyId: String
    var ownerUserId: String
    var dealRoomId: String?
    var title: String
    var status: OfferStatus
    var currentRevisionId: String?
    var clientDecision: OfferClientDecision
    var expiresAt: Date?
    var submittedAt: Date?
    var isActive: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case ownerUserId = "owner_user_id"
        case dealRoomId = "deal_room_id"
        case title
        case status
        case currentRevisionId = "current_revision_id"
        case clientDecision = "client_decision"
        case expiresAt = "expires_at"
        case submittedAt = "submitted_at"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isTerminal: Bool {
        status.isTerminal
    }
}

struct OfferRevision: Identifiable, Codable, Hashable {
    var id: String?
    var offerId: String
    var revisionNumber: Int
    var purchasePrice: Double
    var earnestMoney: Double?
    var downPaymentPercent: Double?
    var closingCostCredit: Double?
    var optionPeriodDays: Int?
    var inspectionPeriodDays: Int?
    var financingContingencyDays: Int?
    var appraisalContingency: Bool
    var sellerConcessions: Double?
    var estimatedCloseDate: Date?
    var notes: String?
    var createdByUserId: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case revisionNumber = "revision_number"
        case purchasePrice = "purchase_price"
        case earnestMoney = "earnest_money"
        case downPaymentPercent = "down_payment_percent"
        case closingCostCredit = "closing_cost_credit"
        case optionPeriodDays = "option_period_days"
        case inspectionPeriodDays = "inspection_period_days"
        case financingContingencyDays = "financing_contingency_days"
        case appraisalContingency = "appraisal_contingency"
        case sellerConcessions = "seller_concessions"
        case estimatedCloseDate = "estimated_close_date"
        case notes
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
    }
}

struct OfferComment: Identifiable, Codable, Hashable {
    var id: String?
    var offerId: String
    var authorUserId: String
    var body: String
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case authorUserId = "author_user_id"
        case body
        case createdAt = "created_at"
    }
}

struct OfferActivityEvent: Identifiable, Codable, Hashable {
    var id: String?
    var offerId: String
    var actorUserId: String
    var eventType: String
    var metadata: [String: String]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case actorUserId = "actor_user_id"
        case eventType = "event_type"
        case metadata
        case createdAt = "created_at"
    }
}

struct OfferDetailPayload: Codable, Hashable {
    var revisions: [OfferRevision]
    var comments: [OfferComment]
    var activity: [OfferActivityEvent]
}

struct OfferRevisionDraft: Hashable {
    var purchasePrice: Double
    var earnestMoney: Double?
    var downPaymentPercent: Double?
    var closingCostCredit: Double?
    var optionPeriodDays: Int?
    var inspectionPeriodDays: Int?
    var financingContingencyDays: Int?
    var appraisalContingency: Bool
    var sellerConcessions: Double?
    var estimatedCloseDate: Date?
    var notes: String?

    init(
        purchasePrice: Double,
        earnestMoney: Double? = nil,
        downPaymentPercent: Double? = nil,
        closingCostCredit: Double? = nil,
        optionPeriodDays: Int? = nil,
        inspectionPeriodDays: Int? = nil,
        financingContingencyDays: Int? = nil,
        appraisalContingency: Bool = false,
        sellerConcessions: Double? = nil,
        estimatedCloseDate: Date? = nil,
        notes: String? = nil
    ) {
        self.purchasePrice = purchasePrice
        self.earnestMoney = earnestMoney
        self.downPaymentPercent = downPaymentPercent
        self.closingCostCredit = closingCostCredit
        self.optionPeriodDays = optionPeriodDays
        self.inspectionPeriodDays = inspectionPeriodDays
        self.financingContingencyDays = financingContingencyDays
        self.appraisalContingency = appraisalContingency
        self.sellerConcessions = sellerConcessions
        self.estimatedCloseDate = estimatedCloseDate
        self.notes = notes
    }

    static func from(property: Property) -> OfferRevisionDraft {
        OfferRevisionDraft(
            purchasePrice: property.purchasePrice,
            earnestMoney: nil,
            downPaymentPercent: property.downPaymentPercent,
            closingCostCredit: nil,
            optionPeriodDays: nil,
            inspectionPeriodDays: nil,
            financingContingencyDays: nil,
            appraisalContingency: false,
            sellerConcessions: nil,
            estimatedCloseDate: nil,
            notes: nil
        )
    }
}

enum OfferStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case readyToSubmit = "ready_to_submit"
    case submitted
    case counterReceived = "counter_received"
    case accepted
    case rejected
    case withdrawn
    case expired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft:
            return "Draft"
        case .readyToSubmit:
            return "Ready"
        case .submitted:
            return "Submitted"
        case .counterReceived:
            return "Counter"
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Rejected"
        case .withdrawn:
            return "Withdrawn"
        case .expired:
            return "Expired"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .accepted, .rejected, .withdrawn, .expired:
            return true
        default:
            return false
        }
    }

    var chipColor: String {
        switch self {
        case .draft, .readyToSubmit:
            return "yellow"
        case .submitted, .counterReceived:
            return "blue"
        case .accepted:
            return "green"
        case .rejected, .withdrawn, .expired:
            return "red"
        }
    }
}

enum OfferClientDecision: String, Codable, CaseIterable, Identifiable {
    case undecided
    case approvedToSubmit = "approved_to_submit"
    case needsRevision = "needs_revision"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .undecided:
            return "Undecided"
        case .approvedToSubmit:
            return "Approved"
        case .needsRevision:
            return "Needs Revision"
        }
    }
}

extension OfferActivityEvent {
    var displayTitle: String {
        switch eventType {
        case "offer_created":
            return "Offer created"
        case "revision_created":
            return "Revision saved"
        case "status_changed":
            return "Status updated"
        case "client_decision_changed":
            return "Client recommendation updated"
        case "comment_added":
            return "Comment added"
        case "offer_archived":
            return "Offer archived"
        default:
            return eventType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
