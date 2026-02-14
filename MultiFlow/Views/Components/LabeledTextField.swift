import SwiftUI

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    private let ink = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.7))
            TextField("", text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .foregroundStyle(ink)
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
