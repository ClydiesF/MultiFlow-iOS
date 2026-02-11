import SwiftUI

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    private let ink = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0)
    private let mutedInk = Color(red: 92.0 / 255.0, green: 92.0 / 255.0, blue: 98.0 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(mutedInk)
            TextField("", text: $text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .foregroundStyle(ink)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
        }
    }
}
