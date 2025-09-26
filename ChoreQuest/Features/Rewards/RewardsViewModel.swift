import Foundation
import Combine

final class RewardsViewModel: ObservableObject {

    @Published private(set) var rewards: [Reward]

    init(rewards: [Reward] = Reward.previewList) {
        self.rewards = rewards
    }

    func add(_ reward: Reward) {
        rewards.append(reward)
    }

    func remove(_ reward: Reward) {
        rewards.removeAll { $0.id == reward.id }
    }

    func remove(ids rewardIDs: Set<UUID>) {
        guard !rewardIDs.isEmpty else { return }
        rewards.removeAll { rewardIDs.contains($0.id) }
    }

    func update(_ reward: Reward) {
        guard let index = rewards.firstIndex(where: { $0.id == reward.id }) else { return }
        rewards[index] = reward
    }
}
