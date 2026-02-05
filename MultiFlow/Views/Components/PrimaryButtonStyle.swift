import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.richBlack)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primaryYellow)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
