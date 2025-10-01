import SwiftUI
import Combine

final class FamilyViewModel: ObservableObject {

    @Published private(set) var kids: [Kid]

    // MARK: - Family/Account
    @Published var familyInviteCode: String = ""

    init(kids: [Kid] = []) {
        self.kids = kids
    }

    func replaceKids(_ kids: [Kid]) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.kids = kids
        }
    }

    func addKid(
        name: String,
        color: Color,
        choresViewModel: ChoresViewModel,
        assignedChoreIDs: Set<UUID>
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newKid = Kid(
            name: trimmedName,
            colorHex: color.hexString ?? Kid.defaultColorHex,
            coins: 0
        )
        kids.append(newKid)
        choresViewModel.addKid(trimmedName)
        performAssignmentUpdate(forKidNamed: trimmedName, with: assignedChoreIDs, choresViewModel: choresViewModel)
    }

    func updateKid(
        _ kid: Kid,
        originalKid: Kid,
        choresViewModel: ChoresViewModel,
        assignedChoreIDs: Set<UUID>
    ) {
        guard let index = kids.firstIndex(where: { $0.id == kid.id }) else { return }
        kids[index] = kid

        if originalKid.name != kid.name {
            choresViewModel.renameKid(from: originalKid.name, to: kid.name)
        }

        performAssignmentUpdate(forKidNamed: kid.name, with: assignedChoreIDs, choresViewModel: choresViewModel)
    }

    func removeKid(_ kid: Kid, choresViewModel: ChoresViewModel) {
        kids.removeAll { $0.id == kid.id }
        choresViewModel.removeKid(named: kid.name)
    }

    func addCoins(toKidNamed name: String, delta: Int) {
        guard !name.isEmpty, delta != 0 else { return }
        if let idx = kids.firstIndex(where: { $0.name == name }) {
            kids[idx].coins += delta
        }
    }

    func updateAssignments(
        forKidNamed kidName: String,
        with selectedChoreIDs: Set<UUID>,
        choresViewModel: ChoresViewModel
    ) {
        performAssignmentUpdate(forKidNamed: kidName, with: selectedChoreIDs, choresViewModel: choresViewModel)
    }

    // MARK: - Family management stubs
    func createFamily(named name: String) {
        // TODO: Implement family creation logic
        // For now, generate a mock invite code
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        familyInviteCode = String(trimmed.prefix(3)).uppercased() + "-" + UUID().uuidString.prefix(5).uppercased()
    }

    func joinFamily(with code: String) {
        // TODO: Implement join logic
        // For now, accept any non-empty code
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        familyInviteCode = trimmed.uppercased()
    }

    func logout() {
        // TODO: Implement logout
        kids.removeAll()
        familyInviteCode = ""
    }
}

private extension FamilyViewModel {
    func performAssignmentUpdate(
        forKidNamed kidName: String,
        with selectedChoreIDs: Set<UUID>,
        choresViewModel: ChoresViewModel
    ) {
        guard !kidName.isEmpty else { return }

        for chore in choresViewModel.chores {
            var updatedChore = chore
            var assignees = Set(updatedChore.assignedTo)

            if selectedChoreIDs.contains(chore.id) {
                if assignees.insert(kidName).inserted {
                    updatedChore.assignedTo = choresViewModel.orderedAssignees(from: assignees)
                    choresViewModel.update(updatedChore)
                }
            } else {
                if assignees.remove(kidName) != nil {
                    updatedChore.assignedTo = choresViewModel.orderedAssignees(from: assignees)
                    choresViewModel.update(updatedChore)
                }
            }
        }
    }
}
