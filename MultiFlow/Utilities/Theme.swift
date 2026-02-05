import SwiftUI

extension Color {
    static let primaryYellow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(red: 1.0, green: 0.82, blue: 0.2, alpha: 1.0)
        : UIColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1.0)
    })

    static let richBlack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.94, alpha: 1.0)
        : UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1.0)
    })

    static let canvasWhite = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.06, alpha: 1.0)
        : UIColor.white
    })

    static let softGray = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.16, alpha: 1.0)
        : UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
    })

    static let cardSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.12, alpha: 1.0)
        : UIColor.white
    })
}
