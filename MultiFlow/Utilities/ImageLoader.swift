import UIKit
import ImageIO

enum ImageLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 180
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    static func loadImage(from urlString: String?, maxPixelSize: CGFloat? = nil) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let cacheKey = cacheKey(for: urlString, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: cacheKey as NSString) {
            return cached
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 15

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let image = downsampledImage(from: data, maxPixelSize: maxPixelSize) else {
                return nil
            }

            cache.setObject(image, forKey: cacheKey as NSString, cost: imageCost(for: image))
            return image
        } catch {
            return nil
        }
    }

    private static func cacheKey(for urlString: String, maxPixelSize: CGFloat?) -> String {
        let sizePart = Int((maxPixelSize ?? 0).rounded())
        return "\(urlString)#\(sizePart)"
    }

    private static func downsampledImage(from data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        let sourceOptions: CFDictionary = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }

        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ]

        if let maxPixelSize, maxPixelSize > 0 {
            options[kCGImageSourceThumbnailMaxPixelSize] = max(128, Int(maxPixelSize.rounded()))
        }

        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }

        return UIImage(data: data)
    }

    private static func imageCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
