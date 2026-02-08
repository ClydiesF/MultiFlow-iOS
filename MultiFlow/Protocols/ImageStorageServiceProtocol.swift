import Foundation
import UIKit

struct UploadedImage {
    let path: String
    let signedURL: URL
}

protocol ImageStorageServiceProtocol {
    func uploadPropertyImage(_ image: UIImage, userId: String, propertyId: String?) async throws -> UploadedImage
    func signedURL(for path: String) async throws -> URL
}
