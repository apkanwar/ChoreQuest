import SwiftUI

struct KidsCard: View {
    let kids: [Kid]
    var onOpen: (Kid) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Kids")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.bottom, 4)

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
        .padding(20)
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }
}

#if DEBUG
#Preview("Kids Card") {
    KidsCard(kids: Kid.previewList, onOpen: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("Kids Card Empty") {
    KidsCard(kids: [], onOpen: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}
#endif
