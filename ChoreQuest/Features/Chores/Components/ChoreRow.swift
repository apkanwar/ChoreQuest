import SwiftUI

struct ChoreRow: View {
    let chore: Chore
    @Environment(\.colorScheme) private var colorScheme

    private var iconColor: Color {
        let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]
        let seed = chore.icon.isEmpty ? chore.name : chore.icon
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    var body: some View {
        let bgTint = Color.blue.opacity(colorScheme == .dark ? 0.14 : 0.08)

        HStack(spacing: 14) {
            Circle()
                .fill(iconColor.opacity(0.3))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(chore.icon.isEmpty ? "🧩" : chore.icon)
                        .font(.title2)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(chore.name)
                    .font(.headline)
                    .bold()

                metaLine

                rewardLine
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(bgTint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }

    private var metaLine: some View {
        let assignee = chore.assignedTo.isEmpty ? "Unassigned" : chore.assignedTo
        let dateText = chore.dueDate.formatted(.dateTime.month(.abbreviated).day())

        return HStack(spacing: 10) {
            Label {
                Text(assignee).bold()
            } icon: {
                Image(systemName: "person")
            }
            .labelStyle(.titleAndIcon)
            Divider().frame(height: 12)
            Label {
                Text(dateText).bold()
            } icon: {
                Image(systemName: "calendar")
            }
            .labelStyle(.titleAndIcon)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var rewardLine: some View {
        HStack(spacing: 12) {
            Label("+\(chore.rewardCoins)", systemImage: "star.circle")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.3))
                )
            Divider().frame(height: 12)
            Label("-\(chore.punishmentCoins)", systemImage: "exclamationmark.triangle")
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.3))
                )
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview("Chore Row") {
    ChoreRow(chore: .preview)
        .padding()
        .previewLayout(.sizeThatFits)
}
#endif

