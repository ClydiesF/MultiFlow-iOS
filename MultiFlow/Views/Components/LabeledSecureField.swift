import SwiftUI

struct LabeledSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            SecureField("", text: $text)
                .textContentType(.password)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.softGray)
                )
        }
    }
}
