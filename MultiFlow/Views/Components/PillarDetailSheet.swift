import SwiftUI

struct PillarDetailSheet: View {
    let result: PillarResult

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    valuesSection
                    explanationSection
                }
                .padding(20)
            }
            .background(Color.canvasWhite.ignoresSafeArea())
            .navigationTitle("Pillar Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(result.isMetForDisplay ? Color.primaryYellow.opacity(0.16) : Color.softGray)
                    .frame(width: 52, height: 52)
                Image(systemName: result.pillar.iconSystemName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(result.isMetForDisplay ? Color.primaryYellow : Color.richBlack.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.pillar.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)

                Text(result.status.label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(result.isMetForDisplay ? Color.primaryYellow : Color.richBlack.opacity(0.58))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(result.isMetForDisplay ? Color.primaryYellow.opacity(0.14) : Color.softGray)
                    )
            }
            Spacer()
        }
    }

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Proof")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if result.pillar == .cashFlow {
                HStack(spacing: 10) {
                    metricCard(title: "Monthly", value: currencyString(result.monthlyValue))
                    metricCard(title: "Annual", value: currencyString(result.annualValue))
                }
                if let threshold = result.thresholdValue {
                    metricCard(title: "Break-even Threshold", value: "\(currencyString(threshold))/mo")
                }
            } else {
                if let value = result.value {
                    metricCard(title: "Primary Value", value: currencyString(value))
                } else {
                    metricCard(title: "Primary Value", value: "Needs inputs")
                }
            }
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Explanation")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            Text(result.detail)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if result.status == .needsInput {
                Text("Complete missing assumptions in Analysis Edit to fully evaluate this pillar.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.55))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.richBlack.opacity(0.08), lineWidth: 1)
        )
    }

    private func currencyString(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#Preview {
    PillarDetailSheet(
        result: PillarResult(
            pillar: .cashFlow,
            status: .met,
            detail: "Delta vs threshold: +$355/mo",
            value: 4260,
            monthlyValue: 355,
            annualValue: 4260,
            thresholdValue: 250
        )
    )
}
