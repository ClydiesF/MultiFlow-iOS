import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class PropertyStore: ObservableObject {
    
    @Published var properties: [Property] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastDeletedProperty: Property?

    private var listener: ListenerRegistration?

    func listen() {
        isLoading = true
        errorMessage = nil

        listener?.remove()
        listener = Firestore.firestore()
            .collection("properties")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.properties = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Property.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func addProperty(_ property: Property) async throws {
        let collection = Firestore.firestore().collection("properties")
        _ = try collection.addDocument(from: property)
    }

    func updateProperty(_ property: Property) async throws {
        guard let id = property.id else { return }
        let docRef = Firestore.firestore().collection("properties").document(id)
        try docRef.setData(from: property, merge: true)
    }

    func deleteProperty(_ property: Property) async throws {
        guard let id = property.id else { return }
        // Fire toast first so the UI has time to react before the snapshot updates.
        lastDeletedProperty = property
        try await Firestore.firestore().collection("properties").document(id).delete()
    }

    func restoreProperty(_ property: Property) async throws {
        let collection = Firestore.firestore().collection("properties")
        if let id = property.id {
            let docRef = collection.document(id)
            try docRef.setData(from: property, merge: true)
        } else {
            _ = try collection.addDocument(from: property)
        }
    }

    func clearLastDeleted() {
        lastDeletedProperty = nil
    }
}
