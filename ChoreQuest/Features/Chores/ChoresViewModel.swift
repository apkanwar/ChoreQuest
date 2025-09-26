import Foundation
import Combine

final class ChoresViewModel: ObservableObject {

    @Published private(set) var chores: [Chore]
    @Published private(set) var availableKids: [String]

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

    func addKid(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !availableKids.contains(trimmed) {
            availableKids.append(trimmed)
        }
    }

    func renameKid(from oldName: String, to newName: String) {
        let trimmedNew = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldName.isEmpty, !trimmedNew.isEmpty else { return }
        if let index = availableKids.firstIndex(of: oldName) {
            availableKids[index] = trimmedNew
        } else if !availableKids.contains(trimmedNew) {
            availableKids.append(trimmedNew)
        }

        for index in chores.indices where chores[index].assignedTo.contains(oldName) {
            chores[index].assignedTo = chores[index].assignedTo.map { $0 == oldName ? trimmedNew : $0 }
        }
    }

    func removeKid(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        availableKids.removeAll { $0 == trimmed }
        for index in chores.indices {
            chores[index].assignedTo.removeAll { $0 == trimmed }
        }
    }

    func orderedAssignees(from names: Set<String>) -> [String] {
        let ordered = availableKids.filter { names.contains($0) }
        let extras = names.subtracting(ordered)
        return ordered + extras.sorted()
    }
}
