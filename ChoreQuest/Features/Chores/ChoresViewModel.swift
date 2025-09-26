import Foundation
import Combine

final class ChoresViewModel: ObservableObject {
    
    @Published private(set) var chores: [Chore]
    let availableKids: [String]

    init(
        chores: [Chore] = Chore.previewList,
        availableKids: [String] = ["Akam", "Ashley", "Sunny"]
    ) {
        self.chores = chores
        self.availableKids = availableKids
    }

    func add(_ chore: Chore) {
        chores.append(chore)
    }

    func remove(_ chore: Chore) {
        chores.removeAll { $0.id == chore.id }
    }

    func remove(ids choreIDs: Set<UUID>) {
        guard !choreIDs.isEmpty else { return }
        chores.removeAll { choreIDs.contains($0.id) }
    }

    func update(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[index] = chore
    }

    func assign(ids: Set<UUID>, to assignee: String) {
        let assignees = assignee.isEmpty ? [] : [assignee]
        for index in chores.indices where ids.contains(chores[index].id) {
            chores[index].assignedTo = assignees
        }
    }
}
