import SwiftUI

struct ChoresCard: View {
    let chores: [Chore]
    var onAdd: () -> Void
    var onEdit: (Chore) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Chores")
                    .font(.title3.bold())
                Spacer()
                Button(action: onAdd) {
                    Label("Add Chore", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.blue.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            ForEach(chores) { chore in
                Button {
                    onEdit(chore)
                } label: {
                    ChoreRow(chore: chore)
                }
                .buttonStyle(.plain)
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

#if DEBUG
#Preview("Chores Card") {
    ChoresCard(
        chores: Chore.previewList,
        onAdd: {},
        onEdit: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
