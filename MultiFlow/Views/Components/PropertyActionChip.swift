import SwiftUI

struct PropertyActionChip: View {
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let badgeText: String?
    var isEmphasized = false
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconBadgeFill)
                            .frame(width: 28, height: 28)

                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(iconForeground)
                    }

                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.richBlack.opacity(0.68))
                    } else if isEmphasized {
                        Circle()
                            .fill((statusColor ?? Color.primaryYellow).opacity(0.95))
                            .frame(width: 7, height: 7)
                            .shadow(color: (statusColor ?? Color.primaryYellow).opacity(0.45), radius: 6, x: 0, y: 0)
                    }
                }

                HStack(spacing: 8) {
                    if let subtitle, !subtitle.isEmpty {
                        HStack(spacing: 6) {
                            if let statusColor {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                            }

                            Text(subtitle)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.72))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    if let badgeText, !badgeText.isEmpty {
                        Text(badgeText)
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(badgeFill)
                            )
                    }
                }
            }
            .frame(minWidth: 118, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor, lineWidth: isEmphasized ? 1.25 : 1)
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        (statusColor ?? Color.primaryYellow).opacity(isEmphasized ? 0.18 : 0.08),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: shadowColor, radius: isEmphasized ? 14 : 8, x: 0, y: isEmphasized ? 8 : 4)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: Color {
        isEmphasized ? Color.cardSurface.opacity(0.98) : Color.cardSurface
    }

    private var borderColor: Color {
        if isEmphasized {
            return (statusColor ?? Color.primaryYellow).opacity(0.42)
        }
        return Color.richBlack.opacity(0.08)
    }

    private var shadowColor: Color {
        if isEmphasized {
            return (statusColor ?? Color.primaryYellow).opacity(0.2)
        }
        return Color.black.opacity(0.08)
    }

    private var iconBadgeFill: Color {
        if isEmphasized {
            return (statusColor ?? Color.primaryYellow).opacity(0.18)
        }
        return Color.softGray
    }

    private var iconForeground: Color {
        statusColor ?? (isEmphasized ? Color.primaryYellow : Color.richBlack)
    }

    private var badgeFill: Color {
        if isLocked {
            return Color.softGray
        }
        return (statusColor ?? Color.primaryYellow).opacity(isEmphasized ? 0.22 : 0.14)
    }

    private var badgeForeground: Color {
        isLocked ? Color.richBlack.opacity(0.7) : (statusColor ?? Color.richBlack)
    }
}
