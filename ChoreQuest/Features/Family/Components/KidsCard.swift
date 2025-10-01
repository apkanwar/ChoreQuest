import SwiftUI

struct KidsCard: View {
    let kids: [Kid]
    var onOpen: (Kid) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Kids")
            if kids.isEmpty {
                emptyState
            } else {
                ForEach(kids) { kid in
                    Button {
                        onOpen(kid)
                    } label: {
                        KidRow(kid: kid)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appCardStyle()
    }
}

private extension KidsCard {
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No kids yet")
                .font(.headline)
            Text("Add family members to start assigning chores and rewards.")
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
#Preview("Kids Card") {
    KidsCard(kids: Kid.previewList, onOpen: { _ in })
        .padding()
        .background(AppColors.background)
}

#Preview("Kids Card Empty") {
    KidsCard(kids: [], onOpen: { _ in })
        .padding()
        .background(AppColors.background)
}
#endif
