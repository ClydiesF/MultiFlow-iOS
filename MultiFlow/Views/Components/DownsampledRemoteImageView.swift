import SwiftUI

struct DownsampledRemoteImageView<Placeholder: View>: View {
    let urlString: String?
    let maxPixelSize: CGFloat
    let contentMode: ContentMode
    let placeholder: Placeholder

    @State private var uiImage: UIImage?

    init(
        urlString: String?,
        maxPixelSize: CGFloat,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.urlString = urlString
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: taskID) {
            uiImage = await ImageLoader.loadImage(from: urlString, maxPixelSize: maxPixelSize)
        }
    }

    private var taskID: String {
        let urlPart = urlString ?? ""
        let sizePart = Int(maxPixelSize.rounded())
        return "\(urlPart)#\(sizePart)"
    }
}
