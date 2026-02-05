import UIKit

enum ImageLoader {
    static func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}
