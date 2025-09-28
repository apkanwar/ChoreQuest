import SwiftUI

struct RewardsCard: View {
    let rewards: [Reward]
    var onEdit: (Reward) -> Void
    var isSelectingForDeletion: Bool = false
    var selectedRewardIDs: Set<UUID> = []
    var onToggleSelection: (Reward) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Rewards")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.bottom, 4)

            if rewards.isEmpty {
                emptyState
            } else {
                ForEach(rewards) { reward in
                    if isSelectingForDeletion {
                        Button {
                            onToggleSelection(reward)
                        } label: {
                            RewardRow(
                                reward: reward,
                                isSelecting: true,
                                isSelected: selectedRewardIDs.contains(reward.id)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onEdit(reward)
                        } label: {
                            RewardRow(reward: reward)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
        )
        .background(
            Group {
                if #available(iOS 18.0, macOS 15.0, *) {
                    Color.clear.glassEffect()
                }
            }
        )
    }
}

private extension RewardsCard {
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No rewards yet")
                .font(.headline)
            Text("Add rewards to motivate kids to complete chores.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.all, 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

#if DEBUG
#Preview("Rewards Card") {
    RewardsCard(
        rewards: Reward.previewList,
        onEdit: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Rewards Card Selecting") {
    RewardsCard(
        rewards: Reward.previewList,
        onEdit: { _ in },
        isSelectingForDeletion: true,
        selectedRewardIDs: Set([Reward.previewList.first?.id].compactMap { $0 }),
        onToggleSelection: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Rewards Card Empty") {
    RewardsCard(
        rewards: [],
        onEdit: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
