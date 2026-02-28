import Foundation

protocol OfferRepositoryProtocol: AnyObject {
    func fetchActiveOfferCount(userId: String) async throws -> Int
    func fetchOffers(propertyId: String, userId: String) async throws -> [PropertyOffer]
    func fetchOfferDetail(offerId: String, userId: String) async throws -> OfferDetailPayload
    func createOffer(
        propertyId: String,
        userId: String,
        title: String,
        dealRoomId: String?,
        initialRevision: OfferRevisionDraft
    ) async throws -> PropertyOffer
    func createRevision(offerId: String, userId: String, draft: OfferRevisionDraft) async throws -> OfferRevision
    func updateOfferStatus(offerId: String, userId: String, status: OfferStatus) async throws
    func updateClientDecision(offerId: String, userId: String, decision: OfferClientDecision) async throws
    func addComment(offerId: String, userId: String, body: String) async throws
    func deleteComment(commentId: String, userId: String) async throws
    func archiveOffer(offerId: String, userId: String) async throws
    func startListening(propertyId: String, userId: String, onChange: @escaping @Sendable () -> Void) async throws
    func stopListening() async
}
