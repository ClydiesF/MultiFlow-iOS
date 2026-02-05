import UIKit
import SwiftUI

struct PDFService {
    static func renderDealSummary(
        property: Property,
        metrics: DealMetrics,
        image: UIImage?,
        cashflowBreakEvenThreshold: Double,
        gradeProfileName: String?,
        gradeProfileColorHex: String?
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 36
            var cursorY: CGFloat = margin

            let title = "Deal Summary"
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold)
            ]
            let titleSize = title.size(withAttributes: titleAttributes)
            title.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: titleAttributes)

            cursorY += titleSize.height + 16

            let addressAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .medium)
            ]
            property.address.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: addressAttributes)
            cursorY += 28

            let imageHeight: CGFloat = 150
            let imageRect = CGRect(x: margin, y: cursorY, width: pageRect.width - 2 * margin, height: imageHeight)
            if let image {
                let aspect = image.size.width / max(image.size.height, 1)
                let targetWidth = imageRect.height * aspect
                let drawRect = CGRect(
                    x: imageRect.minX,
                    y: imageRect.minY,
                    width: min(imageRect.width, targetWidth),
                    height: imageRect.height
                )
                image.draw(in: drawRect)
            } else {
                UIColor(white: 0.95, alpha: 1).setFill()
                UIBezierPath(rect: imageRect).fill()
                let placeholder = "No Image"
                let placeholderAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.darkGray
                ]
                let placeholderSize = placeholder.size(withAttributes: placeholderAttrs)
                let placeholderPoint = CGPoint(
                    x: imageRect.midX - placeholderSize.width / 2,
                    y: imageRect.midY - placeholderSize.height / 2
                )
                placeholder.draw(at: placeholderPoint, withAttributes: placeholderAttrs)
            }

            cursorY += imageHeight + 24

            let gradeTitle = "Grade:"
            let gradeTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
            ]
            let gradeValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold)
            ]

            gradeTitle.draw(at: CGPoint(x: margin, y: cursorY), withAttributes: gradeTitleAttributes)
            metrics.grade.rawValue.draw(at: CGPoint(x: margin + 70, y: cursorY - 2), withAttributes: gradeValueAttributes)

            if let name = gradeProfileName {
                let badgeX = margin + 120
                let badgeY = cursorY - 2
                let badgePaddingX: CGFloat = 10
                let badgePaddingY: CGFloat = 4
                let badgeFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
                let badgeAttrs: [NSAttributedString.Key: Any] = [
                    .font: badgeFont,
                    .foregroundColor: UIColor.black
                ]
                let textSize = name.size(withAttributes: badgeAttrs)
                let badgeRect = CGRect(
                    x: badgeX,
                    y: badgeY,
                    width: textSize.width + badgePaddingX * 2,
                    height: textSize.height + badgePaddingY * 2
                )
                let color = UIColor(Color(hex: gradeProfileColorHex ?? "#FFDD00FF"))
                color.withAlphaComponent(0.25).setFill()
                UIBezierPath(roundedRect: badgeRect, cornerRadius: badgeRect.height / 2).fill()
                let textPoint = CGPoint(x: badgeRect.minX + badgePaddingX, y: badgeRect.minY + badgePaddingY)
                name.draw(at: textPoint, withAttributes: badgeAttrs)
            }

            cursorY += 32

            let tableTop = cursorY
            let tableWidth = pageRect.width - 2 * margin
            let columnGap: CGFloat = 20
            let columnWidth = (tableWidth - columnGap) / 2

            let rowHeight: CGFloat = 30
            let headerHeight: CGFloat = 22
            let rowPaddingY: CGFloat = 6

            let totalMonthlyRent = property.rentRoll.reduce(0) { $0 + $1.monthlyRent }
            let totalAnnualRent = totalMonthlyRent * 12.0
            let monthlyCashFlow = metrics.annualCashFlow / 12.0

            let mortgageBreakdown: MortgageBreakdown? = {
                guard let downPayment = property.downPaymentPercent,
                      let interestRate = property.interestRate else { return nil }
                return MetricsEngine.mortgageBreakdown(
                    purchasePrice: property.purchasePrice,
                    downPaymentPercent: downPayment,
                    interestRate: interestRate,
                    loanTermYears: Double(property.loanTermYears ?? 30),
                    annualTaxes: property.annualTaxes ?? (property.annualTaxesInsurance ?? 0),
                    annualInsurance: property.annualInsurance ?? 0
                )
            }()

            let monthlyPI = mortgageBreakdown.map { $0.monthlyPrincipal + $0.monthlyInterest }
            let annualPrincipalPaydown = mortgageBreakdown?.annualPrincipal ?? 0

            let appreciationRate = property.appreciationRate ?? 0
            let annualAppreciation = max(property.purchasePrice * (appreciationRate / 100.0), 0)
            let equityGain = annualPrincipalPaydown + annualAppreciation

            let taxBenefit: Double? = {
                guard let taxRate = property.marginalTaxRate,
                      let landPercent = property.landValuePercent else { return nil }
                let basis = max(property.purchasePrice * (1.0 - landPercent / 100.0), 0)
                let annualDepreciation = basis / 27.5
                return annualDepreciation * (taxRate / 100.0)
            }()

            let pillarEvaluation: PillarEvaluation? = {
                guard let breakdown = mortgageBreakdown else { return nil }
                return EvaluatorEngine.evaluate(
                    purchasePrice: property.purchasePrice,
                    annualCashFlow: metrics.annualCashFlow,
                    annualPrincipalPaydown: breakdown.annualPrincipal,
                    appreciationRate: appreciationRate,
                    cashflowBreakEvenThreshold: cashflowBreakEvenThreshold,
                    marginalTaxRate: property.marginalTaxRate,
                    landValuePercent: property.landValuePercent
                )
            }()

            struct RowItem {
                let key: String
                let value: String?
                let isPillars: Bool
            }

            struct Section {
                let title: String
                let rows: [RowItem]
            }

            let sections: [Section] = [
                Section(title: "Performance", rows: [
                    RowItem(key: "Cap Rate", value: percentString(metrics.capRate), isPillars: false),
                    RowItem(key: "Cash-on-Cash", value: percentString(metrics.cashOnCash), isPillars: false),
                    RowItem(key: "NOI", value: currencyString(metrics.netOperatingIncome), isPillars: false),
                    RowItem(key: "DCR", value: String(format: "%.2f", metrics.debtCoverageRatio), isPillars: false)
                ]),
                Section(title: "Cash Flow", rows: [
                    RowItem(key: "Monthly Cash Flow", value: currencyString(monthlyCashFlow), isPillars: false),
                    RowItem(key: "Annual Cash Flow", value: currencyString(metrics.annualCashFlow), isPillars: false),
                    RowItem(key: "Total Monthly Rent", value: currencyString(totalMonthlyRent), isPillars: false),
                    RowItem(key: "Total Annual Rent", value: currencyString(totalAnnualRent), isPillars: false)
                ]),
                Section(title: "Debt", rows: [
                    RowItem(key: "Monthly P&I", value: monthlyPI.map(currencyString) ?? "N/A", isPillars: false),
                    RowItem(key: "Monthly Taxes", value: mortgageBreakdown.map { currencyString($0.monthlyTaxes) } ?? "N/A", isPillars: false),
                    RowItem(key: "Monthly Insurance", value: mortgageBreakdown.map { currencyString($0.monthlyInsurance) } ?? "N/A", isPillars: false),
                    RowItem(key: "Monthly Total", value: mortgageBreakdown.map { currencyString($0.monthlyTotal) } ?? "N/A", isPillars: false)
                ]),
                Section(title: "Equity", rows: [
                    RowItem(key: "Equity Gain (Annual)", value: currencyString(equityGain), isPillars: false),
                    RowItem(key: "Tax Incentive (Annual)", value: taxBenefit.map(currencyString) ?? "N/A", isPillars: false)
                ]),
                Section(title: "Pillars", rows: [
                    RowItem(key: "Pillars (CF / MP / EQ / TAX)", value: nil, isPillars: true)
                ])
            ]

            let keyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium)
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ]
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]

            func headerColor(for title: String) -> UIColor {
                switch title {
                case "Performance":
                    return UIColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1.0)
                case "Cash Flow":
                    return UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)
                case "Debt":
                    return UIColor.darkGray
                case "Equity":
                    return UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
                case "Pillars":
                    return UIColor.black
                default:
                    return UIColor.darkGray
                }
            }

            var columnX: CGFloat = margin
            var currentY: CGFloat = tableTop
            let maxY = pageRect.height - margin

            func drawHeader(_ title: String) {
                let headerRect = CGRect(x: columnX, y: currentY, width: columnWidth, height: headerHeight)
                var attrs = headerAttributes
                attrs[.foregroundColor] = headerColor(for: title)
                title.draw(in: headerRect, withAttributes: attrs)
                currentY += headerHeight
            }

            func drawRow(_ row: RowItem, index: Int) {
                let rowRect = CGRect(x: columnX, y: currentY, width: columnWidth, height: rowHeight)
                UIColor(white: index % 2 == 0 ? 0.96 : 1.0, alpha: 1).setFill()
                UIBezierPath(rect: rowRect).fill()

                let keyRect = CGRect(x: rowRect.minX + 8, y: rowRect.minY + rowPaddingY, width: columnWidth * 0.6 - 16, height: rowHeight - 2 * rowPaddingY)
                row.key.draw(in: keyRect, withAttributes: keyAttributes)

                let valueRect = CGRect(x: rowRect.minX + columnWidth * 0.6, y: rowRect.minY + rowPaddingY, width: columnWidth * 0.4 - 8, height: rowHeight - 2 * rowPaddingY)

                if row.isPillars, let evaluation = pillarEvaluation {
                    let map = Dictionary(uniqueKeysWithValues: evaluation.results.map { ($0.pillar, $0.status) })
                    let ordered: [Pillar] = [.cashFlow, .mortgagePaydown, .equity, .taxIncentives]
                    let labels = ["CF", "MP", "EQ", "TAX"]

                    let iconSize: CGFloat = 14
                    let spacing: CGFloat = 8
                    var iconX = valueRect.minX

                    func icon(for status: PillarStatus) -> UIImage? {
                        let name: String
                        switch status {
                        case .met: name = "checkmark.circle.fill"
                        case .notMet: name = "xmark.circle.fill"
                        case .needsInput: name = "questionmark.circle"
                        case .borderline: name = "exclamationmark.circle.fill"
                        }
                        return UIImage(systemName: name)
                    }

                    func tint(for status: PillarStatus) -> UIColor {
                        switch status {
                        case .met: return UIColor.systemGreen
                        case .notMet: return UIColor.systemGray
                        case .needsInput: return UIColor.systemGray2
                        case .borderline: return UIColor.systemOrange
                        }
                    }

                    for (index, pillar) in ordered.enumerated() {
                        let status = map[pillar] ?? .needsInput
                        if let img = icon(for: status) {
                            let drawRect = CGRect(x: iconX, y: valueRect.midY - iconSize / 2 - 4, width: iconSize, height: iconSize)
                            img.withTintColor(tint(for: status), renderingMode: .alwaysOriginal).draw(in: drawRect)
                        }

                        let label = labels[index]
                        let labelRect = CGRect(x: iconX - 2, y: valueRect.midY + 6, width: iconSize + 6, height: 10)
                        let labelAttrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
                            .foregroundColor: UIColor.darkGray
                        ]
                        label.draw(in: labelRect, withAttributes: labelAttrs)

                        iconX += iconSize + spacing
                    }
                } else {
                    row.value?.draw(in: valueRect, withAttributes: valueAttributes)
                }

                currentY += rowHeight
            }

            var globalRowIndex = 0
            for section in sections {
                if currentY + headerHeight + rowHeight > maxY {
                    columnX = margin + columnWidth + columnGap
                    currentY = tableTop
                }

                drawHeader(section.title)

                for row in section.rows {
                    if currentY + rowHeight > maxY {
                        columnX = margin + columnWidth + columnGap
                        currentY = tableTop
                        drawHeader(section.title)
                    }
                    drawRow(row, index: globalRowIndex)
                    globalRowIndex += 1
                }

                currentY += 6
            }
        }

        let filename = "Deal-Summary-\(UUID().uuidString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    private static func currencyString(_ value: Double) -> String {
        Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? "$0"
    }

    private static func percentString(_ value: Double) -> String {
        Formatters.percent.string(from: NSNumber(value: value)) ?? "0%"
    }
}
