import SwiftUI

extension View {
    func cardStyle() -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.cardSurface)
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
            )
    }
}
