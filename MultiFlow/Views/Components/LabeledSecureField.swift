import SwiftUI

struct LabeledSecureField: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @Binding var text: String
    private let ink = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0)
    private var inputTextColor: Color { colorScheme == .dark ? .white : ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            SecureField("", text: $text)
                .textContentType(.password)
                .foregroundStyle(inputTextColor)
                .tint(Color.primaryYellow)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.softGray)
                )
        }
    }
}
