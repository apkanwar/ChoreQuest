import SwiftUI

struct ChoresCard: View {
    let chores: [Chore]
    var onEdit: (Chore) -> Void
    var isSelectingForDeletion: Bool = false
    var selectedChoreIDs: Set<UUID> = []
    var onToggleSelection: (Chore) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Chores")
            if chores.isEmpty {
                emptyState
            } else {
                ForEach(chores) { chore in
                    if isSelectingForDeletion {
                        Button {
                            onToggleSelection(chore)
                        } label: {
                            ChoreRow(
                                chore: chore,
                                isSelecting: true,
                                isSelected: selectedChoreIDs.contains(chore.id)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            onEdit(chore)
                        } label: {
                            ChoreRow(chore: chore)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCardStyle()
    }
}

private extension ChoresCard {
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No chores yet")
                .font(.headline)
            Text("Add chores and assign them to kids.")
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
#Preview("Chores Card") {
    ChoresCard(
        chores: Chore.previewList,
        onEdit: { _ in }
    )
    .padding()
    .background(AppColors.background)
}

#Preview("Chores Card Selecting") {
    ChoresCard(
        chores: Chore.previewList,
        onEdit: { _ in },
        isSelectingForDeletion: true,
        selectedChoreIDs: Set([Chore.previewList.first?.id].compactMap { $0 }),
        onToggleSelection: { _ in }
    )
    .padding()
    .background(AppColors.background)
}

#Preview("Chores Card Empty") {
    ChoresCard(
        chores: [],
        onEdit: { _ in }
    )
    .padding()
    .background(AppColors.background)
}
#endif
