import Foundation
import UIKit
import FirebaseStorage

enum ImageUploadError: LocalizedError {
    case invalidImageData
    case firebase(code: StorageErrorCode, message: String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Unable to prepare the image for upload."
        case .firebase(let code, let message):
            return message.isEmpty ? "Upload failed (\(code))." : message
        case .unknown(let message):
            return message.isEmpty ? "Upload failed." : message
        }
    }
}

enum ImageUploadService {
    static func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> URL {
        let storage = Storage.storage()
        let id = propertyId ?? UUID().uuidString
        let path = "property_images/\(id)-\(UUID().uuidString).jpg"
        let ref = storage.reference(withPath: path)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ImageUploadError.invalidImageData
        }

        do {
            _ = try await ref.putDataAsync(data, metadata: nil)
            return try await ref.downloadURL()
        } catch {
            let ns = error as NSError
            if ns.domain == StorageErrorDomain, let code = StorageErrorCode(rawValue: ns.code) {
                let message: String
                switch code {
                case .unauthenticated:
                    message = "Please sign in to upload photos."
                case .unauthorized:
                    message = "You don’t have permission to upload photos."
                case .quotaExceeded:
                    message = "Storage quota exceeded."
                case .retryLimitExceeded:
                    message = "Upload timed out. Check your connection and try again."
                case .cancelled:
                    message = "Upload was cancelled."
                default:
                    message = ns.localizedDescription
                }
                throw ImageUploadError.firebase(code: code, message: message)
            }
            throw ImageUploadError.unknown(message: ns.localizedDescription)
        }
    }
}
