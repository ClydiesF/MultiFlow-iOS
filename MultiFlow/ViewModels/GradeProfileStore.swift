import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class GradeProfileStore: ObservableObject {
    @Published var profiles: [GradeProfile] = []
    @Published var defaultProfileId: String?
    @Published var isLoading = false

    private let repository: GradeProfileRepositoryProtocol

    init(repository: GradeProfileRepositoryProtocol = SupabaseGradeProfileRepository()) {
        self.repository = repository
    }

    func listen() {
        guard let userId = currentUserId else {
            profiles = []
            defaultProfileId = nil
            return
        }

        isLoading = true

        Task {
            await reload()
            isLoading = false

            do {
                try await repository.startListening(for: userId) { [weak self] in
                    Task { @MainActor in
                        await self?.reload()
                    }
                }
            } catch {
                // Keep UX non-blocking; data already loaded once if available.
            }
        }
    }

    func stopListening() {
        Task { await repository.stopListening() }
    }

    func addProfile(_ profile: GradeProfile) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        let id = try await repository.addProfile(profile, userId: userId)
        if defaultProfileId == nil {
            try await setDefaultProfileId(id)
        }
    }

    func updateProfile(_ profile: GradeProfile) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        try await repository.updateProfile(profile, userId: userId)
    }

    func deleteProfile(_ profile: GradeProfile) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        guard let id = profile.id else { return }

        try await repository.deleteProfile(id: id, userId: userId)

        if id == defaultProfileId {
            let fallback = profiles.first { $0.id != id }?.id
            try await setDefaultProfileId(fallback)
        }
    }

    func setDefaultProfile(_ profile: GradeProfile) async throws {
        try await setDefaultProfileId(profile.id)
    }

    func setDefaultProfileId(_ id: String?) async throws {
        guard let userId = currentUserId else { throw BackendError.notAuthenticated }
        try await repository.setDefaultProfileId(id, userId: userId)
    }

    func effectiveProfile(for property: Property) -> GradeProfile {
        if let overrideId = property.gradeProfileId,
           let profile = profiles.first(where: { $0.id == overrideId }) {
            return profile
        }
        if let defaultId = defaultProfileId,
           let profile = profiles.first(where: { $0.id == defaultId }) {
            return profile
        }
        return profiles.first ?? GradeProfile.defaultProfile
    }

    private func reload() async {
        guard let userId = currentUserId else {
            profiles = []
            defaultProfileId = nil
            return
        }

        do {
            profiles = try await repository.fetchProfiles(for: userId)
            defaultProfileId = try await repository.fetchDefaultProfileId(for: userId)
        } catch {
            // Keep existing values on transient failures.
        }
    }

    private var currentUserId: String? {
        SupabaseManager.shared.client.auth.currentUser?.id.uuidString
    }
}
