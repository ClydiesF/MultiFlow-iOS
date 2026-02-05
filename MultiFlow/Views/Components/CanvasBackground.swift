import SwiftUI

struct CanvasBackground: View {
    var body: some View {
        ZStack {
            Color.canvasWhite.ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.02)
                .blendMode(.overlay)
                .ignoresSafeArea()

            Circle()
                .fill(Color.primaryYellow.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 10)
                .offset(x: 140, y: -220)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.softGray.opacity(0.9))
                .frame(width: 300, height: 210)
                .rotationEffect(.degrees(-18))
                .offset(x: -150, y: 220)

            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
                .frame(width: 340, height: 190)
                .rotationEffect(.degrees(12))
                .offset(x: 120, y: 260)
        }
    }
}

#Preview {
    CanvasBackground()
}
