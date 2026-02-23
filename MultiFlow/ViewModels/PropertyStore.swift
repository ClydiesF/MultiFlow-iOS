import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class PropertyStore: ObservableObject {
    @Published var properties: [Property] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastDeletedProperty: Property?

    private let repository: PropertyRepositoryProtocol
    private let client: SupabaseClient

    init(repository: PropertyRepositoryProtocol, client: SupabaseClient) {
        self.repository = repository
        self.client = client
    }

    @MainActor
    convenience init(repository: PropertyRepositoryProtocol = SupabasePropertyRepository()) {
        self.init(repository: repository, client: SupabaseManager.shared.client)
    }

    func listen() {
        guard let userId = currentUserId else {
            properties = []
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                properties = try await repository.fetchProperties(for: userId)
                isLoading = false

                try await repository.startListening(for: userId) { [weak self] in
                    Task { @MainActor in
                        await self?.reload()
                    }
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopListening() {
        Task { await repository.stopListening() }
    }

    func addProperty(_ property: Property) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        try await repository.addProperty(property, userId: userId)

        // Optimistically surface the newly added property so Portfolio updates immediately.
        var optimistic = property
        optimistic.userId = userId
        if optimistic.id == nil {
            optimistic.id = UUID().uuidString
        }
        properties.insert(optimistic, at: 0)

        await reload()
    }

    func updateProperty(_ property: Property) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        try await repository.updateProperty(property, userId: userId)

        if let id = property.id,
           let index = properties.firstIndex(where: { $0.id == id }) {
            properties[index] = property
        }

        // Re-fetch so derived fields (e.g. signed image URLs / server-normalized values)
        // are reflected even if realtime delivery is delayed or unavailable.
        await reload()
    }

    func deleteProperty(_ property: Property) async throws {
        guard let id = property.id else { return }
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        lastDeletedProperty = property
        try await repository.deleteProperty(id: id, userId: userId)
    }

    func restoreProperty(_ property: Property) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        if property.id == nil {
            try await repository.addProperty(property, userId: userId)
        } else {
            try await repository.updateProperty(property, userId: userId)
        }
    }

    func clearLastDeleted() {
        lastDeletedProperty = nil
    }

    private func reload() async {
        guard let userId = currentUserId else {
            properties = []
            return
        }

        do {
            properties = try await repository.fetchProperties(for: userId)
            errorMessage = nil
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

enum BackendError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        }
    }
}
