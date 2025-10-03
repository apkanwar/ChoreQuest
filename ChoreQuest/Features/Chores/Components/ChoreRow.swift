import SwiftUI

struct ChoreRow: View {
    let chore: Chore
    var isSelecting: Bool = false
    var isSelected: Bool = false

    private var accentColor: Color {
        let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]
        let seed = chore.icon.isEmpty ? chore.name : chore.icon
        var hash = 0
        for scalar in seed.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        let index = abs(hash) % palette.count
        return palette[index]
    }

    private var rowBackground: Color {
        if isSelecting, isSelected {
            return Color.accentColor.opacity(0.25)
        }
        return AppColors.rowAccent
    }

    var body: some View {
        HStack(spacing: 14) {
            leadingContent

            VStack(alignment: .leading, spacing: 6) {
                Text(chore.name)
                    .font(.headline)

                metaLine

                rewardLine
            }

            Spacer()

            if !isSelecting {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .appRowBackground(color: rowBackground)
        .opacity(chore.paused ? 0.6 : 1.0)
        .contentShape(Rectangle())
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }

    @ViewBuilder
    private var leadingContent: some View {
        if isSelecting {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24, weight: .semibold))
                .frame(width: 46, height: 46)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        } else {
            VStack(spacing: 4) {
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(chore.icon.isEmpty ? "🧩" : chore.icon)
                            .font(.title2)
                    )

                Text(chore.frequency.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 60)
        }
    }

    private var metaLine: some View {
        let assignee = chore.assignedTo.isEmpty ? "Unassigned" : chore.assignedTo.joined(separator: ", ")
        let dateText = chore.dueDate.formatted(.dateTime.month(.abbreviated).day())

        return HStack(spacing: 10) {
            Label(assignee, systemImage: "person")
            Divider().frame(height: 12)
            Label(dateText, systemImage: "calendar")
            if chore.paused {
                Divider().frame(height: 12)
                Label("Paused", systemImage: "pause.circle")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var rewardLine: some View {
        HStack(spacing: 12) {
            Label("+\(chore.rewardCoins)", systemImage: "star.circle")
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.green.opacity(0.25)))

            Divider().frame(height: 12)

            Label("-\(chore.punishmentCoins)", systemImage: "exclamationmark.triangle")
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange.opacity(0.25)))
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#if DEBUG
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
#Preview("Chore Row", traits: .sizeThatFitsLayout) {
    ChoreRow(chore: .preview)
        .padding()
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
#Preview("Chore Row Selecting", traits: .sizeThatFitsLayout) {
    ChoreRow(chore: .preview, isSelecting: true, isSelected: true)
        .padding()
}

// Fallback previews for earlier OS versions
struct ChoreRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChoreRow(chore: .preview)
                .padding()
                .previewDisplayName("Chore Row")

            ChoreRow(chore: .preview, isSelecting: true, isSelected: true)
                .padding()
                .previewDisplayName("Chore Row Selecting")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
