import SwiftUI

struct PropertyActionChipModel: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let badgeText: String?
    let isEmphasized: Bool
    let isLocked: Bool
    let action: () -> Void
}

struct PropertyActionChipRowView: View {
    let chips: [PropertyActionChipModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(chips) { chip in
                    PropertyActionChip(
                        icon: chip.icon,
                        title: chip.title,
                        subtitle: chip.subtitle,
                        statusColor: chip.statusColor,
                        badgeText: chip.badgeText,
                        isEmphasized: chip.isEmphasized,
                        isLocked: chip.isLocked,
                        action: chip.action
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}
