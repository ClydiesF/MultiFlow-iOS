import SwiftUI

enum UnitType: String {
    case singleFamily = "Single"
    case duplex = "Duplex"
    case triplex = "Triplex"
    case quadplex = "Quadplex"
    case commercial = "Commercial"

    static func from(unitCount: Int) -> UnitType {
        switch unitCount {
        case 1: return .singleFamily
        case 2: return .duplex
        case 3: return .triplex
        case 4: return .quadplex
        default: return .commercial
        }
    }
}

struct UnitTypeBadge: View {
    let unitCount: Int

    var body: some View {
        Text(UnitType.from(unitCount: unitCount).rawValue)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primaryYellow.opacity(0.7))
            )
    }
}

#Preview {
    UnitTypeBadge(unitCount: 3)
}
