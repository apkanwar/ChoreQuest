import SwiftUI

struct RewardRow: View {
    let reward: Reward
    var isSelecting: Bool = false
    var isSelected: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var iconColor: Color {
        let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]
        let seed = reward.icon.isEmpty ? reward.name : reward.icon
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    private var backgroundTint: Color {
        let base = Color.orange.opacity(colorScheme == .dark ? 0.14 : 0.1)
        guard isSelecting, isSelected else { return base }
        return Color.accentColor.opacity(colorScheme == .dark ? 0.3 : 0.2)
    }

    var body: some View {
        HStack(spacing: 14) {
            leadingContent

            VStack(alignment: .leading, spacing: 6) {
                Text(reward.name)
                    .font(.headline)
                    .bold()

                Text(reward.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                rewardCost
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .opacity(isSelecting ? 0 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(backgroundTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }

    @ViewBuilder
    private var leadingContent: some View {
        if isSelecting {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        } else {
            VStack(spacing: 4) {
                Circle()
                    .fill(iconColor.opacity(0.3))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(reward.icon.isEmpty ? "🎯" : reward.icon)
                            .font(.title2)
                    )
            }
            .frame(width: 60)
        }
    }

    private var rewardCost: some View {
        Label("\(reward.cost) coins", systemImage: "star.circle")
            .labelStyle(.titleAndIcon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.3))
            )
    }
}

#if DEBUG
#Preview("Reward Row", traits: .sizeThatFitsLayout) {
    RewardRow(reward: .preview)
        .padding()
}

#Preview("Reward Row Selecting", traits: .sizeThatFitsLayout) {
    RewardRow(reward: .preview, isSelecting: true, isSelected: true)
        .padding()
}
#endif
