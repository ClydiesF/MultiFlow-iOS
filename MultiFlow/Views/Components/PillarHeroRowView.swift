import SwiftUI

struct PillarHeroRowView: View {
    let evaluation: PillarEvaluation
    var onSelect: (PillarResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule(style: .continuous)
                .fill(Color.primaryYellow)
                .frame(width: 52, height: 5)

            HStack(spacing: 10) {
                ForEach(evaluation.results, id: \.pillar) { result in
                    pillarItem(result)
                }
            }
        }
    }

    private func pillarItem(_ result: PillarResult) -> some View {
        let isMet = result.isMetForDisplay
        return Button {
            onSelect(result)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: result.pillar.iconSystemName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isMet ? Color.primaryYellow : Color.richBlack.opacity(0.46))

                Text(result.pillar.shortTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isMet ? Color.primaryYellow : Color.richBlack.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isMet ? Color.primaryYellow.opacity(0.14) : Color.softGray)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isMet ? Color.primaryYellow.opacity(0.42) : Color.richBlack.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: isMet ? Color.primaryYellow.opacity(0.22) : Color.clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(result.pillar.accessibilityLabel), \(result.status.label)")
        .accessibilityHint("Shows pillar proof and calculation details")
    }
}

#Preview {
    let evaluation = PillarEvaluation(
        results: [
            PillarResult(pillar: .cashFlow, status: .met, detail: "Cash flow is above threshold.", value: 1200, monthlyValue: 100, annualValue: 1200, thresholdValue: 50),
            PillarResult(pillar: .mortgagePaydown, status: .notMet, detail: "No paydown data yet.", value: nil, monthlyValue: nil, annualValue: nil, thresholdValue: nil),
            PillarResult(pillar: .equity, status: .borderline, detail: "Equity is near threshold.", value: 3000, monthlyValue: nil, annualValue: nil, thresholdValue: nil),
            PillarResult(pillar: .taxIncentives, status: .needsInput, detail: "Add marginal tax rate and land value %.", value: nil, monthlyValue: nil, annualValue: nil, thresholdValue: nil)
        ]
    )

    VStack {
        PillarHeroRowView(evaluation: evaluation) { _ in }
    }
    .padding()
    .background(Color.canvasWhite)
}
