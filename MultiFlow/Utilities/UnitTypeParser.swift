import Foundation

enum UnitTypeParser {
    static func bedsBaths(from text: String) -> (beds: Double?, baths: Double?) {
        let lower = text.lowercased()
        let beds = matchNumber(in: lower, pattern: "(\\d+(?:\\.\\d+)?)\\s*br")
        let baths = matchNumber(in: lower, pattern: "(\\d+(?:\\.\\d+)?)\\s*ba")

        if beds == nil, lower.contains("studio") {
            return (0, baths ?? 1)
        }

        return (beds, baths)
    }

    private static func matchNumber(in text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let numberRange = Range(match.range(at: 1), in: text) else { return nil }
        return Double(text[numberRange])
    }
}

enum StateAbbreviationFormatter {
    static func abbreviate(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 2 {
            return trimmed.uppercased()
        }

        let map: [String: String] = [
            "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
            "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
            "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
            "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
            "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
            "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
            "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
            "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
            "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
            "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
            "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
            "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
            "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC"
        ]

        return map[trimmed.lowercased()] ?? trimmed
    }
}
