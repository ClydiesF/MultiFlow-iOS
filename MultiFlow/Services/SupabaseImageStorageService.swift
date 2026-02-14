import Foundation
import UIKit
import Supabase

enum ImageUploadError: LocalizedError {
    case invalidImageData
    case unauthorized
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Unable to prepare the image for upload."
        case .unauthorized:
            return "You do not have permission to upload photos."
        case .unknown(let message):
            return message.isEmpty ? "Upload failed." : message
        }
    }
}

struct SupabaseImageStorageService: ImageStorageServiceProtocol {
    private let client: SupabaseClient
    private let bucket = "property-images"

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func uploadPropertyImage(_ image: UIImage, userId: String, propertyId: String?) async throws -> UploadedImage {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ImageUploadError.invalidImageData
        }

        let propertySegment = propertyId ?? UUID().uuidString
        let path = "\(userId)/\(propertySegment)/\(UUID().uuidString).jpg"

        #if DEBUG
        print("SupabaseImageStorageService.uploadPropertyImage")
        print("  bucket:", bucket)
        print("  userId:", userId)
        print("  propertySegment:", propertySegment)
        print("  uploadPath:", path)
        print("  bytes:", data.count)
        #endif

        do {
            try await client.storage
                .from(bucket)
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))

            let signedURL = try await signedURL(for: path)
            #if DEBUG
            print("  upload success, signedURL:", signedURL.absoluteString)
            #endif
            return UploadedImage(path: path, signedURL: signedURL)
        } catch {
            #if DEBUG
            print("  upload failed:", error.localizedDescription)
            #endif
            throw ImageUploadError.unknown(message: error.localizedDescription)
        }
    }

    func signedURL(for path: String) async throws -> URL {
        try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: 3600)
    }
}
