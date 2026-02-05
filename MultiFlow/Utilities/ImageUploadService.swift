import Foundation
import UIKit
import FirebaseStorage

enum ImageUploadService {
    static func uploadPropertyImage(_ image: UIImage, propertyId: String? = nil) async throws -> URL {
        let storage = Storage.storage()
        let id = propertyId ?? UUID().uuidString
        let path = "property_images/\(id)-\(UUID().uuidString).jpg"
        let ref = storage.reference(withPath: path)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "ImageUpload", code: 1)
        }

        _ = try await ref.putDataAsync(data, metadata: nil)
        return try await ref.downloadURL()
    }
}
