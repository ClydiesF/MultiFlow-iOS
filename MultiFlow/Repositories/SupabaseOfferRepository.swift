import Foundation
import Supabase

final class SupabaseOfferRepository: OfferRepositoryProtocol {
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    convenience init() {
        self.init(client: SupabaseManager.shared.client)
    }

    func fetchActiveOfferCount(userId: String) async throws -> Int {
        let rows: [OfferCountRow] = try await client
            .from("property_offers")
            .select("id")
            .eq("owner_user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value
        return rows.count
    }

    func fetchOffers(propertyId: String, userId: String) async throws -> [PropertyOffer] {
        let rows: [PropertyOfferRow] = try await client
            .from("property_offers")
            .select()
            .eq("property_id", value: propertyId)
            .eq("owner_user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toModel() }
    }

    func fetchOfferDetail(offerId: String, userId: String) async throws -> OfferDetailPayload {
        async let revisionsTask: [OfferRevisionRow] = client
            .from("offer_revisions")
            .select()
            .eq("offer_id", value: offerId)
            .order("revision_number", ascending: false)
            .execute()
            .value

        async let commentsTask: [OfferCommentRow] = client
            .from("offer_comments")
            .select()
            .eq("offer_id", value: offerId)
            .order("created_at", ascending: false)
            .execute()
            .value

        async let activityTask: [OfferActivityRow] = client
            .from("offer_activity")
            .select()
            .eq("offer_id", value: offerId)
            .order("created_at", ascending: false)
            .execute()
            .value

        _ = userId
        let revisions = try await revisionsTask.map { $0.toModel() }
        let comments = try await commentsTask.map { $0.toModel() }
        let activity = try await activityTask.map { $0.toModel() }
        return OfferDetailPayload(revisions: revisions, comments: comments, activity: activity)
    }

    func createOffer(
        propertyId: String,
        userId: String,
        title: String,
        dealRoomId: String?,
        initialRevision: OfferRevisionDraft
    ) async throws -> PropertyOffer {
        let baseRow = PropertyOfferWriteRow(
            propertyId: propertyId,
            ownerUserId: userId,
            dealRoomId: dealRoomId,
            title: title,
            status: OfferStatus.draft.rawValue,
            currentRevisionId: nil,
            clientDecision: OfferClientDecision.undecided.rawValue,
            expiresAt: nil,
            submittedAt: nil,
            isActive: true
        )

        let inserted: PropertyOfferRow = try await client
            .from("property_offers")
            .insert(baseRow)
            .select()
            .single()
            .execute()
            .value

        guard let offerId = inserted.id else {
            throw BackendError.notAuthenticated
        }

        let revision = try await createRevision(offerId: offerId, userId: userId, draft: initialRevision)

        _ = try await client
            .from("property_offers")
            .update(CurrentRevisionUpdateRow(currentRevisionId: revision.id))
            .eq("id", value: offerId)
            .eq("owner_user_id", value: userId)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "offer_created",
            metadata: ["title": title]
        )

        var model = inserted.toModel()
        model.currentRevisionId = revision.id
        return model
    }

    func createRevision(offerId: String, userId: String, draft: OfferRevisionDraft) async throws -> OfferRevision {
        let revisionNumber = (try await fetchNextRevisionNumber(offerId: offerId))
        let row = OfferRevisionWriteRow(
            offerId: offerId,
            revisionNumber: revisionNumber,
            purchasePrice: draft.purchasePrice,
            earnestMoney: draft.earnestMoney,
            downPaymentPercent: draft.downPaymentPercent,
            closingCostCredit: draft.closingCostCredit,
            optionPeriodDays: draft.optionPeriodDays,
            inspectionPeriodDays: draft.inspectionPeriodDays,
            financingContingencyDays: draft.financingContingencyDays,
            appraisalContingency: draft.appraisalContingency,
            sellerConcessions: draft.sellerConcessions,
            estimatedCloseDate: draft.estimatedCloseDate,
            notes: draft.notes,
            createdByUserId: userId
        )

        let inserted: OfferRevisionRow = try await client
            .from("offer_revisions")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        _ = try await client
            .from("property_offers")
            .update(CurrentRevisionUpdateRow(currentRevisionId: inserted.id))
            .eq("id", value: offerId)
            .eq("owner_user_id", value: userId)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "revision_created",
            metadata: ["revision": String(revisionNumber)]
        )

        return inserted.toModel()
    }

    func updateOfferStatus(offerId: String, userId: String, status: OfferStatus) async throws {
        _ = try await client
            .from("property_offers")
            .update(
                OfferStatusUpdateRow(
                    status: status.rawValue,
                    submittedAt: status == .submitted ? Date() : nil,
                    isActive: !status.isTerminal
                )
            )
            .eq("id", value: offerId)
            .eq("owner_user_id", value: userId)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "status_changed",
            metadata: ["status": status.rawValue]
        )
    }

    func updateClientDecision(offerId: String, userId: String, decision: OfferClientDecision) async throws {
        _ = try await client
            .from("property_offers")
            .update(ClientDecisionUpdateRow(clientDecision: decision.rawValue))
            .eq("id", value: offerId)
            .eq("owner_user_id", value: userId)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "client_decision_changed",
            metadata: ["decision": decision.rawValue]
        )
    }

    func addComment(offerId: String, userId: String, body: String) async throws {
        let row = OfferCommentWriteRow(offerId: offerId, authorUserId: userId, body: body)
        _ = try await client
            .from("offer_comments")
            .insert(row)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "comment_added",
            metadata: [:]
        )
    }

    func deleteComment(commentId: String, userId: String) async throws {
        _ = try await client
            .from("offer_comments")
            .delete()
            .eq("id", value: commentId)
            .eq("author_user_id", value: userId)
            .execute()
    }

    func archiveOffer(offerId: String, userId: String) async throws {
        _ = try await client
            .from("property_offers")
            .update(ArchiveOfferUpdateRow(isActive: false, status: OfferStatus.withdrawn.rawValue))
            .eq("id", value: offerId)
            .eq("owner_user_id", value: userId)
            .execute()

        try await insertActivity(
            offerId: offerId,
            userId: userId,
            eventType: "offer_archived",
            metadata: [:]
        )
    }

    func startListening(propertyId: String, userId: String, onChange: @escaping @Sendable () -> Void) async throws {
        await stopListening()

        let channel = client.channel("public:property_offers:\(propertyId):\(userId)")
        self.channel = channel

        listenTask = Task {
            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "property_offers",
                filter: "property_id=eq.\(propertyId)"
            )
            for await _ in changes {
                onChange()
            }
        }

        await channel.subscribe()
    }

    func stopListening() async {
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            await client.removeChannel(channel)
            self.channel = nil
        }
    }

    private func fetchNextRevisionNumber(offerId: String) async throws -> Int {
        let rows: [OfferRevisionNumberRow] = try await client
            .from("offer_revisions")
            .select("revision_number")
            .eq("offer_id", value: offerId)
            .order("revision_number", ascending: false)
            .limit(1)
            .execute()
            .value
        return (rows.first?.revisionNumber ?? 0) + 1
    }

    private func insertActivity(
        offerId: String,
        userId: String,
        eventType: String,
        metadata: [String: String]
    ) async throws {
        let row = OfferActivityWriteRow(
            offerId: offerId,
            actorUserId: userId,
            eventType: eventType,
            metadata: metadata.isEmpty ? nil : metadata
        )
        _ = try await client
            .from("offer_activity")
            .insert(row)
            .execute()
    }
}

private struct OfferCountRow: Codable {
    let id: String?
}

private struct OfferRevisionNumberRow: Codable {
    let revisionNumber: Int

    enum CodingKeys: String, CodingKey {
        case revisionNumber = "revision_number"
    }
}

private struct PropertyOfferRow: Codable {
    let id: String?
    let propertyId: String
    let ownerUserId: String
    let dealRoomId: String?
    let title: String
    let status: OfferStatus
    let currentRevisionId: String?
    let clientDecision: OfferClientDecision
    let expiresAt: Date?
    let submittedAt: Date?
    let isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

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

    func toModel() -> PropertyOffer {
        PropertyOffer(
            id: id,
            propertyId: propertyId,
            ownerUserId: ownerUserId,
            dealRoomId: dealRoomId,
            title: title,
            status: status,
            currentRevisionId: currentRevisionId,
            clientDecision: clientDecision,
            expiresAt: expiresAt,
            submittedAt: submittedAt,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct PropertyOfferWriteRow: Codable {
    let propertyId: String
    let ownerUserId: String
    let dealRoomId: String?
    let title: String
    let status: String
    let currentRevisionId: String?
    let clientDecision: String
    let expiresAt: Date?
    let submittedAt: Date?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
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
    }
}

private struct OfferRevisionRow: Codable {
    let id: String?
    let offerId: String
    let revisionNumber: Int
    let purchasePrice: Double
    let earnestMoney: Double?
    let downPaymentPercent: Double?
    let closingCostCredit: Double?
    let optionPeriodDays: Int?
    let inspectionPeriodDays: Int?
    let financingContingencyDays: Int?
    let appraisalContingency: Bool
    let sellerConcessions: Double?
    let estimatedCloseDate: Date?
    let notes: String?
    let createdByUserId: String
    let createdAt: Date?

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

    func toModel() -> OfferRevision {
        OfferRevision(
            id: id,
            offerId: offerId,
            revisionNumber: revisionNumber,
            purchasePrice: purchasePrice,
            earnestMoney: earnestMoney,
            downPaymentPercent: downPaymentPercent,
            closingCostCredit: closingCostCredit,
            optionPeriodDays: optionPeriodDays,
            inspectionPeriodDays: inspectionPeriodDays,
            financingContingencyDays: financingContingencyDays,
            appraisalContingency: appraisalContingency,
            sellerConcessions: sellerConcessions,
            estimatedCloseDate: estimatedCloseDate,
            notes: notes,
            createdByUserId: createdByUserId,
            createdAt: createdAt
        )
    }
}

private struct OfferRevisionWriteRow: Codable {
    let offerId: String
    let revisionNumber: Int
    let purchasePrice: Double
    let earnestMoney: Double?
    let downPaymentPercent: Double?
    let closingCostCredit: Double?
    let optionPeriodDays: Int?
    let inspectionPeriodDays: Int?
    let financingContingencyDays: Int?
    let appraisalContingency: Bool
    let sellerConcessions: Double?
    let estimatedCloseDate: Date?
    let notes: String?
    let createdByUserId: String

    enum CodingKeys: String, CodingKey {
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
    }
}

private struct OfferCommentRow: Codable {
    let id: String?
    let offerId: String
    let authorUserId: String
    let body: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case authorUserId = "author_user_id"
        case body
        case createdAt = "created_at"
    }

    func toModel() -> OfferComment {
        OfferComment(
            id: id,
            offerId: offerId,
            authorUserId: authorUserId,
            body: body,
            createdAt: createdAt
        )
    }
}

private struct OfferCommentWriteRow: Codable {
    let offerId: String
    let authorUserId: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case authorUserId = "author_user_id"
        case body
    }
}

private struct OfferActivityRow: Codable {
    let id: String?
    let offerId: String
    let actorUserId: String
    let eventType: String
    let metadata: [String: String]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case actorUserId = "actor_user_id"
        case eventType = "event_type"
        case metadata
        case createdAt = "created_at"
    }

    func toModel() -> OfferActivityEvent {
        OfferActivityEvent(
            id: id,
            offerId: offerId,
            actorUserId: actorUserId,
            eventType: eventType,
            metadata: metadata,
            createdAt: createdAt
        )
    }
}

private struct OfferActivityWriteRow: Codable {
    let offerId: String
    let actorUserId: String
    let eventType: String
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case actorUserId = "actor_user_id"
        case eventType = "event_type"
        case metadata
    }
}

private struct CurrentRevisionUpdateRow: Codable {
    let currentRevisionId: String?

    enum CodingKeys: String, CodingKey {
        case currentRevisionId = "current_revision_id"
    }
}

private struct OfferStatusUpdateRow: Codable {
    let status: String
    let submittedAt: Date?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case submittedAt = "submitted_at"
        case isActive = "is_active"
    }
}

private struct ClientDecisionUpdateRow: Codable {
    let clientDecision: String

    enum CodingKeys: String, CodingKey {
        case clientDecision = "client_decision"
    }
}

private struct ArchiveOfferUpdateRow: Codable {
    let isActive: Bool
    let status: String

    enum CodingKeys: String, CodingKey {
        case isActive = "is_active"
        case status
    }
}
