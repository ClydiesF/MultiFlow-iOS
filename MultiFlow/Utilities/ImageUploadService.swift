import Foundation
import UIKit
import Supabase
import Auth

struct ImageUploadService {
    private let client: SupabaseClient
    private let storage: ImageStorageServiceProtocol

    init(client: SupabaseClient, storage: ImageStorageServiceProtocol) {
        self.client = client
        self.storage = storage
    }

    init(client: SupabaseClient) {
        self.client = client
        self.storage = SupabaseImageStorageService(client: client)
    }

    init(storage: ImageStorageServiceProtocol) {
        self.client = SupabaseManager.shared.client
        self.storage = storage
    }

    init() {
        let client = SupabaseManager.shared.client
        self.client = client
        self.storage = SupabaseImageStorageService(client: client)
    }

    func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> UploadedImage {
        #if DEBUG
        print("ImageUploadService.uploadPropertyImage begin")
        print("  propertyId:", propertyId ?? "nil")
        print("  auth.currentUser.id:", client.auth.currentUser?.id.uuidString ?? "nil")
        print("  auth.currentSession.user.id:", client.auth.currentSession?.user.id.uuidString ?? "nil")
        #endif
        guard let userId = client.auth.currentUser?.id.uuidString.lowercased() else {
            throw BackendError.notAuthenticated
        }
        return try await storage.uploadPropertyImage(
            image,
            userId: userId,
            propertyId: propertyId?.lowercased()
        )
    }

    func signedURL(for path: String) async throws -> URL {
        try await storage.signedURL(for: path)
    }

    static func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> UploadedImage {
        try await ImageUploadService().uploadPropertyImage(image, propertyId: propertyId)
    }

    static func signedURL(for path: String) async throws -> URL {
        try await ImageUploadService().signedURL(for: path)
    }
}
