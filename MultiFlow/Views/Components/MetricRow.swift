import SwiftUI

struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
        }
        .foregroundStyle(Color.richBlack)
        .padding(.vertical, 6)
    }
}
