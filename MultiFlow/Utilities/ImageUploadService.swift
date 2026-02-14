import Foundation
import UIKit
import Supabase
import Auth

enum ImageUploadService {
    private static let storage: ImageStorageServiceProtocol = SupabaseImageStorageService()

    static func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> UploadedImage {
        #if DEBUG
        print("ImageUploadService.uploadPropertyImage begin")
        print("  propertyId:", propertyId ?? "nil")
        print("  auth.currentUser.id:", SupabaseManager.shared.client.auth.currentUser?.id.uuidString ?? "nil")
        print("  auth.currentSession.user.id:", SupabaseManager.shared.client.auth.currentSession?.user.id.uuidString ?? "nil")
        #endif
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id.uuidString.lowercased() else {
            throw BackendError.notAuthenticated
        }
        return try await storage.uploadPropertyImage(
            image,
            userId: userId,
            propertyId: propertyId?.lowercased()
        )
    }

    static func signedURL(for path: String) async throws -> URL {
        try await storage.signedURL(for: path)
    }
}
