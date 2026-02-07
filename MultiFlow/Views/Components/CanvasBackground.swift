import SwiftUI

struct CanvasBackground: View {
    @State private var drift = false

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
                .offset(x: drift ? 160 : 140, y: drift ? -210 : -220)
                .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: drift)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(Color.softGray.opacity(0.9))
                .frame(width: 300, height: 210)
                .rotationEffect(.degrees(drift ? -15 : -18))
                .offset(x: drift ? -135 : -150, y: drift ? 230 : 220)
                .animation(.easeInOut(duration: 16).repeatForever(autoreverses: true), value: drift)

            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
                .frame(width: 340, height: 190)
                .rotationEffect(.degrees(drift ? 10 : 12))
                .offset(x: drift ? 110 : 120, y: drift ? 250 : 260)
                .animation(.easeInOut(duration: 18).repeatForever(autoreverses: true), value: drift)
        }
        .onAppear {
            drift = true
        }
    }
}

#Preview {
    CanvasBackground()
}
