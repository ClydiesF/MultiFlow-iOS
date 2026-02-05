import SwiftUI

struct GradeBadge: View {
    let grade: Grade
    let accentColor: Color?

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(accentColor ?? Color.primaryYellow)
    }

    private var symbolName: String {
        switch grade {
        case .a: return "a.circle.fill"
        case .b: return "b.circle.fill"
        case .c: return "c.circle.fill"
        case .dOrF: return "f.circle.fill"
        }
    }
}

extension GradeBadge {
    init(grade: Grade) {
        self.grade = grade
        self.accentColor = nil
    }
}
