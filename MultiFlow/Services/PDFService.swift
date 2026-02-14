import UIKit
import SwiftUI

struct PDFService {
    private struct Palette {
        static let richBlack = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        static let charcoal = UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1)
        static let surface = UIColor(red: 0.14, green: 0.15, blue: 0.19, alpha: 1)
        static let softLine = UIColor(white: 1, alpha: 0.12)
        static let textPrimary = UIColor.white
        static let textSecondary = UIColor(white: 1, alpha: 0.74)
        static let primaryYellow = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
        static let metricBlue = UIColor(red: 0.35, green: 0.69, blue: 0.98, alpha: 1)
        static let metricGreen = UIColor(red: 0.32, green: 0.84, blue: 0.55, alpha: 1)
        static let metricRed = UIColor(red: 1.0, green: 0.36, blue: 0.41, alpha: 1)
        static let neutralFill = UIColor(white: 1, alpha: 0.08)
    }

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

        let monthlyPI = (mortgageBreakdown?.monthlyPrincipal ?? 0) + (mortgageBreakdown?.monthlyInterest ?? 0)
        let monthlyTaxes = mortgageBreakdown?.monthlyTaxes ?? ((property.annualTaxes ?? 0) / 12.0)
        let monthlyInsurance = mortgageBreakdown?.monthlyInsurance ?? ((property.annualInsurance ?? 0) / 12.0)
        let monthlyDebtService = mortgageBreakdown?.monthlyTotal ?? (monthlyPI + monthlyTaxes + monthlyInsurance)
        let monthlyOperatingExpense = max(totalMonthlyRent - metrics.netOperatingIncome / 12.0, 0)

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

        let data = renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext

            let margin: CGFloat = 28
            var cursorY: CGFloat = margin
            let contentWidth = pageRect.width - (margin * 2)

            // Base page background.
            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(pageRect)

            // Header block.
            let headerRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: 112)
            fillRoundedRect(cg: cg, rect: headerRect, radius: 20, color: Palette.charcoal)
            strokeRoundedRect(cg: cg, rect: headerRect, radius: 20, color: Palette.softLine, width: 1)

            let accentRect = CGRect(x: headerRect.minX + 18, y: headerRect.minY + 18, width: 50, height: 6)
            fillRoundedRect(cg: cg, rect: accentRect, radius: 3, color: Palette.primaryYellow)

            drawText(
                "Deal Summary",
                in: CGRect(x: headerRect.minX + 18, y: headerRect.minY + 34, width: headerRect.width - 240, height: 34),
                font: .systemFont(ofSize: 29, weight: .bold),
                color: Palette.textPrimary
            )

            let fullAddress = [property.address, compactLocation(for: property)].filter { !$0.isEmpty }.joined(separator: " | ")
            drawText(
                fullAddress,
                in: CGRect(x: headerRect.minX + 18, y: headerRect.minY + 74, width: headerRect.width - 230, height: 20),
                font: .systemFont(ofSize: 12, weight: .medium),
                color: Palette.textSecondary
            )

            let gradePillRect = CGRect(x: headerRect.maxX - 188, y: headerRect.minY + 18, width: 170, height: 34)
            fillRoundedRect(cg: cg, rect: gradePillRect, radius: 17, color: Palette.primaryYellow.withAlphaComponent(0.2))
            drawText(
                "Grade  \(metrics.grade.rawValue)",
                in: gradePillRect.insetBy(dx: 12, dy: 8),
                font: .systemFont(ofSize: 14, weight: .bold),
                color: Palette.primaryYellow,
                alignment: .center
            )

            if let profileName = gradeProfileName, !profileName.isEmpty {
                let color = UIColor(Color(hex: gradeProfileColorHex ?? "#FFDD00"))
                let profileRect = CGRect(x: headerRect.maxX - 188, y: headerRect.minY + 58, width: 170, height: 34)
                fillRoundedRect(cg: cg, rect: profileRect, radius: 17, color: color.withAlphaComponent(0.16))
                drawText(
                    profileName,
                    in: profileRect.insetBy(dx: 10, dy: 8),
                    font: .systemFont(ofSize: 12, weight: .semibold),
                    color: color,
                    alignment: .center
                )
            }

            cursorY = headerRect.maxY + 14

            // KPI strip.
            let kpiHeight: CGFloat = 84
            let kpiGap: CGFloat = 10
            let kpiWidth = (contentWidth - (kpiGap * 3)) / 4
            let kpis: [(String, String, UIColor)] = [
                ("NOI", currencyString(metrics.netOperatingIncome), Palette.metricGreen),
                ("Cash Flow /mo", currencyString(monthlyCashFlow), monthlyCashFlow >= 0 ? Palette.metricGreen : Palette.metricRed),
                ("Cap Rate", percentString(metrics.capRate), Palette.metricBlue),
                ("DCR", String(format: "%.2f", metrics.debtCoverageRatio), Palette.primaryYellow)
            ]

            for (index, kpi) in kpis.enumerated() {
                let x = margin + (CGFloat(index) * (kpiWidth + kpiGap))
                let cardRect = CGRect(x: x, y: cursorY, width: kpiWidth, height: kpiHeight)
                fillRoundedRect(cg: cg, rect: cardRect, radius: 14, color: Palette.surface)
                strokeRoundedRect(cg: cg, rect: cardRect, radius: 14, color: Palette.softLine, width: 1)

                drawText(
                    kpi.0,
                    in: CGRect(x: cardRect.minX + 12, y: cardRect.minY + 12, width: cardRect.width - 24, height: 16),
                    font: .systemFont(ofSize: 11, weight: .semibold),
                    color: Palette.textSecondary
                )
                drawText(
                    kpi.1,
                    in: CGRect(x: cardRect.minX + 12, y: cardRect.minY + 32, width: cardRect.width - 24, height: 38),
                    font: .systemFont(ofSize: 19, weight: .bold),
                    color: kpi.2
                )
            }

            cursorY += kpiHeight + 14

            // Media + monthly composition area.
            let rowHeight: CGFloat = 190
            let leftWidth = (contentWidth * 0.52).rounded(.down)
            let rightWidth = contentWidth - leftWidth - 10

            let mediaRect = CGRect(x: margin, y: cursorY, width: leftWidth, height: rowHeight)
            fillRoundedRect(cg: cg, rect: mediaRect, radius: 16, color: Palette.surface)
            strokeRoundedRect(cg: cg, rect: mediaRect, radius: 16, color: Palette.softLine, width: 1)

            let imageDrawRect = mediaRect.insetBy(dx: 10, dy: 10)
            if let image {
                drawAspectFill(image: image, in: imageDrawRect)
            } else {
                fillRoundedRect(cg: cg, rect: imageDrawRect, radius: 10, color: Palette.neutralFill)
                drawText(
                    "No Property Image",
                    in: CGRect(x: imageDrawRect.minX, y: imageDrawRect.midY - 8, width: imageDrawRect.width, height: 18),
                    font: .systemFont(ofSize: 13, weight: .semibold),
                    color: Palette.textSecondary,
                    alignment: .center
                )
            }

            let compositionRect = CGRect(x: mediaRect.maxX + 10, y: cursorY, width: rightWidth, height: rowHeight)
            fillRoundedRect(cg: cg, rect: compositionRect, radius: 16, color: Palette.surface)
            strokeRoundedRect(cg: cg, rect: compositionRect, radius: 16, color: Palette.softLine, width: 1)

            drawText(
                "Monthly Composition",
                in: CGRect(x: compositionRect.minX + 12, y: compositionRect.minY + 12, width: compositionRect.width - 24, height: 18),
                font: .systemFont(ofSize: 13, weight: .bold),
                color: Palette.textPrimary
            )

            let compositionItems: [(String, Double, UIColor)] = [
                ("Rent", totalMonthlyRent, Palette.metricBlue),
                ("Operating", monthlyOperatingExpense, UIColor.systemOrange),
                ("Debt", monthlyDebtService, UIColor.systemPink),
                ("Cash Flow", monthlyCashFlow, monthlyCashFlow >= 0 ? Palette.metricGreen : Palette.metricRed)
            ]

            drawBarChart(
                cg: cg,
                rect: CGRect(x: compositionRect.minX + 12, y: compositionRect.minY + 38, width: compositionRect.width - 24, height: 120),
                values: compositionItems
            )

            cursorY += rowHeight + 14

            // Middle row: Pillars + assumptions.
            let middleHeight: CGFloat = 124
            let leftMiddleWidth = (contentWidth * 0.46).rounded(.down)
            let rightMiddleWidth = contentWidth - leftMiddleWidth - 10

            let pillarRect = CGRect(x: margin, y: cursorY, width: leftMiddleWidth, height: middleHeight)
            fillRoundedRect(cg: cg, rect: pillarRect, radius: 14, color: Palette.surface)
            strokeRoundedRect(cg: cg, rect: pillarRect, radius: 14, color: Palette.softLine, width: 1)
            drawText(
                "4-Pillar Snapshot",
                in: CGRect(x: pillarRect.minX + 12, y: pillarRect.minY + 10, width: pillarRect.width - 24, height: 18),
                font: .systemFont(ofSize: 13, weight: .bold),
                color: Palette.textPrimary
            )

            drawPillarLegend(
                cg: cg,
                in: CGRect(x: pillarRect.minX + 12, y: pillarRect.minY + 36, width: pillarRect.width - 24, height: 74),
                evaluation: pillarEvaluation
            )

            let assumptionRect = CGRect(x: pillarRect.maxX + 10, y: cursorY, width: rightMiddleWidth, height: middleHeight)
            fillRoundedRect(cg: cg, rect: assumptionRect, radius: 14, color: Palette.surface)
            strokeRoundedRect(cg: cg, rect: assumptionRect, radius: 14, color: Palette.softLine, width: 1)
            drawText(
                "Core Inputs",
                in: CGRect(x: assumptionRect.minX + 12, y: assumptionRect.minY + 10, width: assumptionRect.width - 24, height: 18),
                font: .systemFont(ofSize: 13, weight: .bold),
                color: Palette.textPrimary
            )

            let assumptions: [String] = [
                "Purchase: \(currencyString(property.purchasePrice))",
                "Down: \(percentString(property.downPaymentPercent ?? 0))",
                "Rate: \(percentString(property.interestRate ?? 0))",
                "Term: \(property.loanTermYears ?? 30)y",
                "Taxes: \(currencyString((property.annualTaxes ?? 0) / 12.0))/mo",
                "Insurance: \(currencyString((property.annualInsurance ?? 0) / 12.0))/mo"
            ]

            var assumptionY = assumptionRect.minY + 34
            for assumption in assumptions {
                drawText(
                    assumption,
                    in: CGRect(x: assumptionRect.minX + 12, y: assumptionY, width: assumptionRect.width - 24, height: 14),
                    font: .systemFont(ofSize: 11, weight: .medium),
                    color: Palette.textSecondary
                )
                assumptionY += 14
            }

            cursorY += middleHeight + 14

            // Bottom row: Rent roll summary + unit preview.
            let bottomRect = CGRect(x: margin, y: cursorY, width: contentWidth, height: pageRect.height - margin - cursorY)
            fillRoundedRect(cg: cg, rect: bottomRect, radius: 14, color: Palette.surface)
            strokeRoundedRect(cg: cg, rect: bottomRect, radius: 14, color: Palette.softLine, width: 1)

            drawText(
                "Rent Roll",
                in: CGRect(x: bottomRect.minX + 12, y: bottomRect.minY + 10, width: bottomRect.width - 24, height: 18),
                font: .systemFont(ofSize: 13, weight: .bold),
                color: Palette.textPrimary
            )

            let summaryY = bottomRect.minY + 30
            let taxBenefitValue: String
            if let taxBenefit {
                taxBenefitValue = currencyString(taxBenefit)
            } else {
                taxBenefitValue = "N/A"
            }
            let summaryItems: [(String, String)] = [
                ("Units", "\(max(property.rentRoll.count, 1))"),
                ("Monthly Rent", currencyString(totalMonthlyRent)),
                ("Annual Rent", currencyString(totalAnnualRent)),
                ("Equity Gain", currencyString(equityGain)),
                ("Tax Benefit", taxBenefitValue)
            ]

            let summaryGap: CGFloat = 8
            let summaryWidth = (bottomRect.width - 24 - (summaryGap * 4)) / 5
            for (index, item) in summaryItems.enumerated() {
                let x = bottomRect.minX + 12 + (CGFloat(index) * (summaryWidth + summaryGap))
                let chip = CGRect(x: x, y: summaryY, width: summaryWidth, height: 44)
                fillRoundedRect(cg: cg, rect: chip, radius: 10, color: Palette.neutralFill)
                drawText(
                    item.0,
                    in: CGRect(x: chip.minX + 8, y: chip.minY + 6, width: chip.width - 16, height: 12),
                    font: .systemFont(ofSize: 9, weight: .semibold),
                    color: Palette.textSecondary,
                    alignment: .center
                )
                drawText(
                    item.1,
                    in: CGRect(x: chip.minX + 8, y: chip.minY + 18, width: chip.width - 16, height: 18),
                    font: .systemFont(ofSize: 11, weight: .bold),
                    color: Palette.textPrimary,
                    alignment: .center
                )
            }

            drawRentRollTable(
                cg: cg,
                rect: CGRect(x: bottomRect.minX + 12, y: summaryY + 52, width: bottomRect.width - 24, height: bottomRect.height - 64),
                rentRoll: property.rentRoll
            )
        }

        let filename = "Deal-Summary-\(UUID().uuidString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    private static func drawPillarLegend(cg: CGContext, in rect: CGRect, evaluation: PillarEvaluation?) {
        let rows: [(String, PillarStatus)] = {
            let map = Dictionary(uniqueKeysWithValues: evaluation?.results.map { ($0.pillar, $0.status) } ?? [])
            return [
                ("Cash Flow", map[.cashFlow] ?? .needsInput),
                ("Paydown", map[.mortgagePaydown] ?? .needsInput),
                ("Equity", map[.equity] ?? .needsInput),
                ("Tax", map[.taxIncentives] ?? .needsInput)
            ]
        }()

        let rowHeight = rect.height / CGFloat(rows.count)
        for (index, row) in rows.enumerated() {
            let rowRect = CGRect(x: rect.minX, y: rect.minY + (CGFloat(index) * rowHeight), width: rect.width, height: rowHeight - 2)
            let isMet = row.1 == .met
            let chipColor = isMet ? Palette.primaryYellow.withAlphaComponent(0.24) : Palette.neutralFill
            fillRoundedRect(cg: cg, rect: rowRect, radius: 8, color: chipColor)

            drawText(
                row.0,
                in: CGRect(x: rowRect.minX + 10, y: rowRect.minY + 6, width: rowRect.width - 80, height: rowRect.height - 12),
                font: .systemFont(ofSize: 11, weight: .semibold),
                color: isMet ? Palette.primaryYellow : Palette.textSecondary
            )

            drawText(
                pillarStatusText(row.1),
                in: CGRect(x: rowRect.maxX - 66, y: rowRect.minY + 6, width: 56, height: rowRect.height - 12),
                font: .systemFont(ofSize: 10, weight: .bold),
                color: isMet ? Palette.primaryYellow : Palette.textSecondary,
                alignment: .right
            )
        }
    }

    private static func drawBarChart(cg: CGContext, rect: CGRect, values: [(String, Double, UIColor)]) {
        let maxValue = max(values.map { abs($0.1) }.max() ?? 1, 1)
        let rowHeight = rect.height / CGFloat(values.count)

        for (index, item) in values.enumerated() {
            let y = rect.minY + CGFloat(index) * rowHeight
            let labelRect = CGRect(x: rect.minX, y: y + 2, width: 66, height: rowHeight - 4)
            drawText(item.0, in: labelRect, font: .systemFont(ofSize: 10, weight: .semibold), color: Palette.textSecondary)

            let trackRect = CGRect(x: rect.minX + 68, y: y + 6, width: rect.width - 68, height: rowHeight - 12)
            fillRoundedRect(cg: cg, rect: trackRect, radius: 4, color: Palette.neutralFill)

            let ratio = CGFloat(min(abs(item.1) / maxValue, 1))
            let fillWidth = max(6, trackRect.width * ratio)
            let barRect = CGRect(x: trackRect.minX, y: trackRect.minY, width: fillWidth, height: trackRect.height)
            fillRoundedRect(cg: cg, rect: barRect, radius: 4, color: item.2.withAlphaComponent(0.92))

            drawText(
                currencyString(item.1),
                in: CGRect(x: trackRect.minX + 6, y: trackRect.minY + 1, width: trackRect.width - 12, height: trackRect.height),
                font: .systemFont(ofSize: 9, weight: .bold),
                color: UIColor.white
            )
        }
    }

    private static func drawRentRollTable(cg: CGContext, rect: CGRect, rentRoll: [RentUnit]) {
        let headerHeight: CGFloat = 22
        let rowHeight: CGFloat = 18
        let colWidths: [CGFloat] = [0.28, 0.26, 0.14, 0.14, 0.18]
        let headers = ["Unit", "Monthly Rent", "Beds", "Baths", "SqFt"]

        fillRoundedRect(cg: cg, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: headerHeight), radius: 8, color: Palette.neutralFill)

        var x = rect.minX + 8
        for (index, header) in headers.enumerated() {
            let width = (rect.width - 16) * colWidths[index]
            drawText(
                header,
                in: CGRect(x: x, y: rect.minY + 4, width: width, height: 14),
                font: .systemFont(ofSize: 9, weight: .bold),
                color: Palette.textSecondary
            )
            x += width
        }

        let rows = Array(rentRoll.prefix(6))
        for (rowIndex, unit) in rows.enumerated() {
            let y = rect.minY + headerHeight + (CGFloat(rowIndex) * rowHeight)
            if rowIndex % 2 == 0 {
                fillRoundedRect(
                    cg: cg,
                    rect: CGRect(x: rect.minX, y: y, width: rect.width, height: rowHeight),
                    radius: 0,
                    color: Palette.neutralFill.withAlphaComponent(0.45)
                )
            }

            let values = [
                unit.unitType.isEmpty ? "Unit \(rowIndex + 1)" : unit.unitType,
                currencyString(unit.monthlyRent),
                String(format: "%.1f", unit.bedrooms),
                String(format: "%.1f", unit.bathrooms),
                unit.squareFeet.map { String(format: "%.0f", $0) } ?? "-"
            ]

            var columnX = rect.minX + 8
            for (index, value) in values.enumerated() {
                let width = (rect.width - 16) * colWidths[index]
                drawText(
                    value,
                    in: CGRect(x: columnX, y: y + 2, width: width, height: rowHeight - 4),
                    font: .systemFont(ofSize: 9, weight: .medium),
                    color: Palette.textPrimary
                )
                columnX += width
            }
        }

        if rentRoll.count > 6 {
            drawText(
                "+ \(rentRoll.count - 6) more unit(s)",
                in: CGRect(x: rect.minX + 8, y: rect.maxY - 14, width: rect.width - 16, height: 12),
                font: .systemFont(ofSize: 9, weight: .semibold),
                color: Palette.textSecondary
            )
        }
    }

    private static func drawAspectFill(image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let widthRatio = rect.width / imageSize.width
        let heightRatio = rect.height / imageSize.height
        let scale = max(widthRatio, heightRatio)

        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        UIBezierPath(roundedRect: rect, cornerRadius: 10).addClip()
        image.draw(in: drawRect)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        text.draw(in: rect, withAttributes: attrs)
    }

    private static func fillRoundedRect(cg: CGContext, rect: CGRect, radius: CGFloat, color: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        cg.saveGState()
        cg.setFillColor(color.cgColor)
        cg.addPath(path.cgPath)
        cg.fillPath()
        cg.restoreGState()
    }

    private static func strokeRoundedRect(cg: CGContext, rect: CGRect, radius: CGFloat, color: UIColor, width: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        cg.saveGState()
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.addPath(path.cgPath)
        cg.strokePath()
        cg.restoreGState()
    }

    private static func compactLocation(for property: Property) -> String {
        var parts: [String] = []
        if let city = property.city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
            parts.append(city)
        }
        if let state = property.state?.trimmingCharacters(in: .whitespacesAndNewlines), !state.isEmpty {
            parts.append(state)
        }
        if let zip = property.zipCode?.trimmingCharacters(in: .whitespacesAndNewlines), !zip.isEmpty {
            parts.append(zip)
        }
        return parts.joined(separator: ", ")
    }

    private static func pillarStatusText(_ status: PillarStatus) -> String {
        switch status {
        case .met:
            return "Met"
        case .notMet:
            return "Not Met"
        case .needsInput:
            return "Needs"
        case .borderline:
            return "Border"
        }
    }

    private static func currencyString(_ value: Double) -> String {
        Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? "$0"
    }

    private static func percentString(_ value: Double) -> String {
        Formatters.percent.string(from: NSNumber(value: value)) ?? "0%"
    }
}
