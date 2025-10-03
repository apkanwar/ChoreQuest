import SwiftUI

struct RewardRow: View {
    let reward: Reward
    var isSelecting: Bool = false
    var isSelected: Bool = false

    private var accentColor: Color {
        let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]
        let seed = reward.icon.isEmpty ? reward.name : reward.icon
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    private var rowBackground: Color {
        if isSelecting, isSelected {
            return Color.accentColor.opacity(0.25)
        }
        return Color.orange.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 14) {
            leadingContent

            VStack(alignment: .leading, spacing: 6) {
                Text(reward.name)
                    .font(.headline)

                if !reward.details.isEmpty {
                    Text(reward.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                rewardCost
            }

            Spacer()

            if !isSelecting {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .appRowBackground(color: rowBackground)
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
            Circle()
                .fill(accentColor.opacity(0.3))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(reward.icon.isEmpty ? "🎯" : reward.icon)
                        .font(.title2)
                )
        }
    }

    private var rewardCost: some View {
        Label("\(reward.cost) coins", systemImage: "star.circle")
            .labelStyle(.titleAndIcon)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.yellow.opacity(0.3)))
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Reward Row", traits: .sizeThatFitsLayout) {
    RewardRow(reward: .preview)
        .padding()
}

@available(iOS 17.0, *)
#Preview("Reward Row Selecting", traits: .sizeThatFitsLayout) {
    RewardRow(reward: .preview, isSelecting: true, isSelected: true)
        .padding()
}
#endif

