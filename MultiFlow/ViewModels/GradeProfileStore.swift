import Foundation
import FirebaseFirestore
internal import Combine

@MainActor
final class GradeProfileStore: ObservableObject {
    @Published var profiles: [GradeProfile] = []
    @Published var defaultProfileId: String?
    @Published var isLoading = false

    private var profileListener: ListenerRegistration?
    private var defaultListener: ListenerRegistration?

    func listen() {
        isLoading = true
        profileListener?.remove()
        defaultListener?.remove()

        profileListener = Firestore.firestore()
            .collection("grade_profiles")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let snapshot {
                    self.profiles = snapshot.documents.compactMap { doc in
                        try? doc.data(as: GradeProfile.self)
                    }
                }
            }

        defaultListener = Firestore.firestore()
            .collection("grade_profile_defaults")
            .document("default")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                if let data = snapshot?.data(),
                   let id = data["defaultProfileId"] as? String {
                    self.defaultProfileId = id
                } else {
                    self.defaultProfileId = nil
                }
            }
    }

    func stopListening() {
        profileListener?.remove()
        defaultListener?.remove()
        profileListener = nil
        defaultListener = nil
    }

    func addProfile(_ profile: GradeProfile) async throws {
        let collection = Firestore.firestore().collection("grade_profiles")
        let ref = try collection.addDocument(from: profile)
        if defaultProfileId == nil {
            try await setDefaultProfileId(ref.documentID)
        }
    }

    func updateProfile(_ profile: GradeProfile) async throws {
        guard let id = profile.id else { return }
        let docRef = Firestore.firestore().collection("grade_profiles").document(id)
        try docRef.setData(from: profile, merge: true)
    }

    func deleteProfile(_ profile: GradeProfile) async throws {
        guard let id = profile.id else { return }
        try await Firestore.firestore().collection("grade_profiles").document(id).delete()

        if id == defaultProfileId {
            // Fallback to first available profile or clear.
            let fallback = profiles.first { $0.id != id }?.id
            try await setDefaultProfileId(fallback)
        }
    }

    func setDefaultProfile(_ profile: GradeProfile) async throws {
        try await setDefaultProfileId(profile.id)
    }

    func setDefaultProfileId(_ id: String?) async throws {
        let docRef = Firestore.firestore().collection("grade_profile_defaults").document("default")
        if let id {
            try await docRef.setData(["defaultProfileId": id], merge: true)
        } else {
            try await docRef.setData(["defaultProfileId": FieldValue.delete()], merge: true)
        }
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
}
