import SwiftUI

struct KidRow: View {
    let kid: Kid

    private var tileBackground: Color {
        kid.color.opacity(0.18)
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(kid.color.opacity(0.3))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(kid.initial)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(kid.name)
                    .font(.headline)
                Text("\(kid.coins) coins saved")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .appRowBackground(color: tileBackground)
        .contentShape(Rectangle())
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }
}

#if DEBUG
#Preview("Kid Row", traits: .sizeThatFitsLayout) {
    KidRow(kid: Kid.previewList.first ?? Kid(name: "Preview", colorHex: Kid.defaultColorHex, coins: 0))
        .padding()
}
#endif
