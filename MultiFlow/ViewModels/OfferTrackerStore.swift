import Foundation
import Combine
import Supabase

@MainActor
final class OfferTrackerStore: ObservableObject {
    @Published var offers: [PropertyOffer] = []
    @Published var revisions: [OfferRevision] = []
    @Published var comments: [OfferComment] = []
    @Published var activity: [OfferActivityEvent] = []
    @Published var selectedOfferId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var activeOfferCount = 0

    private let repository: OfferRepositoryProtocol
    private let client: SupabaseClient
    private var currentPropertyId: String?
    private var isPremium = false

    init(repository: OfferRepositoryProtocol, client: SupabaseClient) {
        self.repository = repository
        self.client = client
    }

    convenience init(repository: OfferRepositoryProtocol) {
        self.init(repository: repository, client: SupabaseManager.shared.client)
    }

    convenience init() {
        self.init(repository: SupabaseOfferRepository(), client: SupabaseManager.shared.client)
    }

    var offerLimit: Int {
        isPremium ? 999 : 1
    }

    var canCreateOffer: Bool {
        activeOfferCount < offerLimit
    }

    var selectedOffer: PropertyOffer? {
        offers.first(where: { $0.id == selectedOfferId }) ?? offers.first
    }

    var currentRevision: OfferRevision? {
        guard let selectedOffer else { return revisions.first }
        if let currentRevisionId = selectedOffer.currentRevisionId,
           let match = revisions.first(where: { $0.id == currentRevisionId }) {
            return match
        }
        return revisions.first
    }

    func setPremium(_ enabled: Bool) {
        isPremium = enabled
    }

    func bind(propertyId: String, isPremium: Bool) async {
        self.isPremium = isPremium

        guard currentPropertyId != propertyId else {
            await refreshOfferCount()
            return
        }

        currentPropertyId = propertyId
        await loadOffers()

        guard let userId = currentUserId else {
            offers = []
            revisions = []
            comments = []
            activity = []
            return
        }

        do {
            try await repository.startListening(propertyId: propertyId, userId: userId) { [weak self] in
                Task { @MainActor in
                    await self?.loadOffers()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        Task { await repository.stopListening() }
    }

    func selectOffer(_ offer: PropertyOffer) async {
        selectedOfferId = offer.id
        await loadSelectedOfferDetail()
    }

    func loadOffers() async {
        guard let propertyId = currentPropertyId,
              let userId = currentUserId else {
            offers = []
            revisions = []
            comments = []
            activity = []
            activeOfferCount = 0
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            async let offersTask = repository.fetchOffers(propertyId: propertyId, userId: userId)
            async let countTask = repository.fetchActiveOfferCount(userId: userId)
            let loadedOffers = try await offersTask
            let count = try await countTask

            offers = loadedOffers
            activeOfferCount = count

            if let selectedOfferId,
               loadedOffers.contains(where: { $0.id == selectedOfferId }) {
                self.selectedOfferId = selectedOfferId
            } else {
                self.selectedOfferId = loadedOffers.first?.id
            }

            errorMessage = nil
            await loadSelectedOfferDetail()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createOffer(title: String, draft: OfferRevisionDraft, dealRoomId: String? = nil) async throws {
        guard canCreateOffer else {
            throw OfferTrackerError.limitReached(limit: offerLimit)
        }
        guard let propertyId = currentPropertyId,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }

        let offer = try await repository.createOffer(
            propertyId: propertyId,
            userId: userId,
            title: title,
            dealRoomId: dealRoomId,
            initialRevision: draft
        )
        selectedOfferId = offer.id
        await loadOffers()
    }

    func createRevision(for offer: PropertyOffer, draft: OfferRevisionDraft) async throws {
        guard let offerId = offer.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        _ = try await repository.createRevision(offerId: offerId, userId: userId, draft: draft)
        selectedOfferId = offerId
        await loadOffers()
    }

    func updateStatus(for offer: PropertyOffer, status: OfferStatus) async throws {
        guard let offerId = offer.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        try await repository.updateOfferStatus(offerId: offerId, userId: userId, status: status)
        await loadOffers()
    }

    func updateClientDecision(for offer: PropertyOffer, decision: OfferClientDecision) async throws {
        guard let offerId = offer.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        try await repository.updateClientDecision(offerId: offerId, userId: userId, decision: decision)
        await loadOffers()
    }

    func addComment(for offer: PropertyOffer, body: String) async throws {
        guard let offerId = offer.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        try await repository.addComment(offerId: offerId, userId: userId, body: body)
        await loadSelectedOfferDetail()
    }

    func deleteComment(_ comment: OfferComment) async throws {
        guard let commentId = comment.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        try await repository.deleteComment(commentId: commentId, userId: userId)
        await loadSelectedOfferDetail()
    }

    func archiveOffer(_ offer: PropertyOffer) async throws {
        guard let offerId = offer.id,
              let userId = currentUserId else {
            throw BackendError.notAuthenticated
        }
        try await repository.archiveOffer(offerId: offerId, userId: userId)
        await loadOffers()
    }

    private func loadSelectedOfferDetail() async {
        guard let offerId = selectedOfferId,
              let userId = currentUserId else {
            revisions = []
            comments = []
            activity = []
            return
        }

        do {
            let payload = try await repository.fetchOfferDetail(offerId: offerId, userId: userId)
            revisions = payload.revisions
            comments = payload.comments
            activity = payload.activity
            errorMessage = nil
        } catch {
            revisions = []
            comments = []
            activity = []
            errorMessage = error.localizedDescription
        }
    }

    private func refreshOfferCount() async {
        guard let userId = currentUserId else {
            activeOfferCount = 0
            return
        }
        do {
            activeOfferCount = try await repository.fetchActiveOfferCount(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var currentUserId: String? {
        if let user = client.auth.currentUser {
            return user.id.uuidString
        }
        if let sessionUser = client.auth.currentSession?.user {
            return sessionUser.id.uuidString
        }
        return nil
    }
}

enum OfferTrackerError: LocalizedError {
    case limitReached(limit: Int)

    var errorDescription: String? {
        switch self {
        case .limitReached(let limit):
            return "Offer limit reached (\(limit))."
        }
    }
}
