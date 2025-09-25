import SwiftUI

struct ChoresHomeView: View {
    @StateObject private var viewModel = ChoresViewModel()

    @State private var showingAddChore = false
    @State private var selectedChore: Chore?

    private let headerHeight: CGFloat = 320

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView {
                        Color.clear.frame(height: headerHeight)
                        ChoresCard(
                            chores: viewModel.chores,
                            onAdd: { showingAddChore = true },
                            onEdit: { selectedChore = $0 }
                        )
                        .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showingAddChore) {
                AddChoreSheet(viewModel: viewModel)
            }
            .sheet(item: $selectedChore) { chore in
                EditChoreSheet(chore: chore, viewModel: viewModel)
            }
        }
    }
}

private extension ChoresHomeView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1000)
    }
}

#if DEBUG
#Preview("Chores Home") {
    ChoresHomeView()
}
#endif

