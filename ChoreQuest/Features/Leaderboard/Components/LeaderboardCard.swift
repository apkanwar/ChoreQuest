import SwiftUI

struct LeaderboardItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let current: Int
    let lifetime: Int
    let color: Color
}

struct LeaderboardCard: View {
    let items: [LeaderboardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Leaderboard")
            if items.isEmpty {
                emptyState
            } else {
                ForEach(items.indices, id: \.self) { index in
                    row(for: index, item: items[index])
                }
            }
        }
    }
}

private extension LeaderboardCard {
    @ViewBuilder
    func row(for index: Int, item: LeaderboardItem) -> some View {
        HStack(spacing: 12) {
            rankBadge(for: index)
            Circle()
                .fill(item.color.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(.subheadline.bold())
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("\(item.current)", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("Lifetime: \(item.lifetime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .appRowBackground()
    }

    func rankBadge(for index: Int) -> some View {
        let rank = index + 1
        let symbol: String
        let color: Color
        switch rank {
        case 1: symbol = "1.circle.fill"; color = .yellow
        case 2: symbol = "2.circle.fill"; color = .gray
        case 3: symbol = "3.circle.fill"; color = .orange
        default: symbol = "\(rank).circle"; color = .secondary
        }
        return Image(systemName: symbol)
            .foregroundStyle(color)
            .font(.title3)
            .frame(width: 28)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No entries yet")
                .font(.headline)
            Text("Complete chores to climb the leaderboard!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .appRowBackground(color: Color(.systemGray5))
    }
}

struct KidsLeaderboardView: View {
    let kids: [LeaderboardItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "Kid Standings")
            if kids.isEmpty {
                ContentUnavailableView("No data", systemImage: "person.3")
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(kids) { kid in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(kid.color.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(kid.name.prefix(1)).uppercased())
                                    .font(.headline.bold())
                                    .foregroundColor(kid.color)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kid.name)
                                .font(.headline)
                            HStack(spacing: 12) {
                                Label("\(kid.current)", systemImage: "star.fill")
                                    .foregroundStyle(.yellow)
                                Label("Lifetime: \(kid.lifetime)", systemImage: "clock")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }
                        Spacer()
                    }
                    .appRowBackground(color: kid.color.opacity(0.15))
                }
            }
        }
    }
}

#if DEBUG
#Preview("Leaderboard Card") {
    LeaderboardCard(items: [
        LeaderboardItem(name: "Alex", current: 20, lifetime: 50, color: .blue),
        LeaderboardItem(name: "Bella", current: 15, lifetime: 40, color: .pink),
        LeaderboardItem(name: "Charlie", current: 10, lifetime: 30, color: .green)
    ])
    .padding()
    .background(AppColors.background)
}

#Preview("Kids Leaderboard View") {
    KidsLeaderboardView(kids: [
        LeaderboardItem(name: "Alex", current: 20, lifetime: 50, color: .blue),
        LeaderboardItem(name: "Bella", current: 15, lifetime: 40, color: .pink),
        LeaderboardItem(name: "Charlie", current: 10, lifetime: 30, color: .green),
        LeaderboardItem(name: "Diana", current: 8, lifetime: 25, color: .purple)
    ])
    .padding()
    .background(AppColors.background)
}
#endif
