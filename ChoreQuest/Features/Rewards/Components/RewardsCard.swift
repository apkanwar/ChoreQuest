import SwiftUI

struct RewardsCard: View {
    let rewards: [Reward]
    var onEdit: (Reward) -> Void
    var isSelectingForDeletion: Bool = false
    var selectedRewardIDs: Set<UUID> = []
    var onToggleSelection: (Reward) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Rewards")
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
        .appCardStyle()
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
        .padding(.vertical, 40)
        .appRowBackground(color: Color(.systemGray5))
    }
}

#if DEBUG
#Preview("Rewards Card") {
    RewardsCard(
        rewards: Reward.previewList,
        onEdit: { _ in }
    )
    .padding()
    .background(AppColors.background)
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
    .background(AppColors.background)
}

#Preview("Rewards Card Empty") {
    RewardsCard(
        rewards: [],
        onEdit: { _ in }
    )
    .padding()
    .background(AppColors.background)
}
#endif
