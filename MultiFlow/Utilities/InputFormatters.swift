import Foundation

enum InputFormatters {
    static func sanitizeDecimal(_ value: String) -> String {
        var filtered = value.filter { $0.isNumber || $0 == "." }
        if let firstDot = filtered.firstIndex(of: ".") {
            let after = filtered.index(after: firstDot)
            filtered = String(filtered[..<after]) + filtered[after...].replacingOccurrences(of: ".", with: "")
        }
        return filtered
    }

    static func formatCurrencyLive(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        if digits.isEmpty { return "" }
        let cents = Double(digits) ?? 0
        let value = cents / 100.0
        return Formatters.currencyTwo.string(from: NSNumber(value: value)) ?? raw
    }


    static func parseCurrency(_ value: String) -> Double? {
        let filtered = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(filtered)
    }

}
