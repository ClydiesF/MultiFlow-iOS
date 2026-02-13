import SwiftUI

struct MetricInfoSheet: View {
    let metric: MetricInfoType
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(Color.primaryYellow)
                                .frame(width: 36, height: 6)
                            Text("Metric Guide")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.6))
                        }

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.primaryYellow.opacity(0.3))
                                    .frame(width: 44, height: 44)
                                Image(systemName: metric.iconName)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.richBlack)
                            }
                            Text(metric.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.richBlack)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Definition")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Text(metric.definition)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.8))
                        }
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Why It Matters")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Text(metric.importance)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(Color.richBlack.opacity(0.8))
                        }
                        .cardStyle()

                        if let formula = metric.formula, !formula.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Formula")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack)
                                Text(formula)
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Color.richBlack.opacity(0.85))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.softGray)
                                    )
                            }
                            .cardStyle()
                        }

                        Button("Done") { dismiss() }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 8)
                    }
                    .padding(24)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appear)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { appear = true }
    }
}

#Preview {
    MetricInfoSheet(metric: .capRate)
}
