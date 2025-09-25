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

    func update(_ chore: Chore) {
        guard let index = chores.firstIndex(where: { $0.id == chore.id }) else { return }
        chores[index] = chore
    }
}
