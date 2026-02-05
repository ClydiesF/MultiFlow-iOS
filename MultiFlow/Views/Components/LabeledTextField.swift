import SwiftUI

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            TextField("", text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.softGray)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
    }
}
