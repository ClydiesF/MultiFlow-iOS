import Foundation
import UIKit
import Supabase
import Auth

enum ImageUploadService {
    private static let storage: ImageStorageServiceProtocol = SupabaseImageStorageService()

    static func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> UploadedImage {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString else {
            throw BackendError.notAuthenticated
        }
        return try await storage.uploadPropertyImage(image, userId: userId, propertyId: propertyId)
    }

    static func signedURL(for path: String) async throws -> URL {
        try await storage.signedURL(for: path)
    }
}
