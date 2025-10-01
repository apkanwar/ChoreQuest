import SwiftUI
import PhotosUI

struct KidChoresView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var choresVM: ChoresViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var isPresentingNotifications = false
    @State private var isPresentingSettings = false

    var body: some View {
        AppScreen {
            choresContent
        }
        .overlay(alignment: .bottom) {
            if isUploading {
                ProgressView("Uploading...")
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .alert("Error", isPresented: isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    // TODO: Show stars wallet
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle.fill")
                            .imageScale(.large)
                        Text("\(currentKidStars)")
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.yellow)
                }
                .accessibilityLabel("Stars \(currentKidStars)")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { isPresentingNotifications = true } label: {
                    Image(systemName: "bell")
                }
                .accessibilityLabel("Notifications")

                Button { isPresentingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $isPresentingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
        }
    }
}

private extension KidChoresView {
    @ViewBuilder
    var choresContent: some View {
        if assignedChores.isEmpty {
            emptyStateCard
        } else {
            choresCard
        }
    }

    var emptyStateCard: some View {
        ContentUnavailableView(
            "No chores assigned",
            systemImage: "checkmark.circle",
            description: Text("Your parent hasn't assigned chores yet.")
        )
        .frame(maxWidth: .infinity)
        .appCardStyle()
    }

    var choresCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            AppSectionHeader(title: "My Chores")
            ForEach(assignedChores) { chore in
                KidChoreRow(chore: chore, isUploading: isUploading) { item in
                    Task { await submit(chore: chore, with: item) }
                }
            }
        }
        .appCardStyle()
    }

    var kidName: String {
        (session.profile?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var assignedChores: [Chore] {
        choresVM.chores.filter { chore in
            let target = kidName.lowercased()
            return chore.assignedTo.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.contains(target)
        }
    }

    var currentKidStars: Int {
        guard let name = session.profile?.displayName else { return 0 }
        return familyVM.kids.first(where: { $0.name == name })?.coins ?? 0
    }

    var isErrorPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    func submit(chore: Chore, with item: PhotosPickerItem) async {
        guard let profile = session.profile, profile.familyId != nil else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { self.errorMessage = "Could not read selected photo." }
            return
        }
        await MainActor.run { self.isUploading = true }
        await session.submitChoreEvidence(chore: chore, photoData: data)
        await MainActor.run { self.isUploading = false }
    }
}

private struct KidChoreRow: View {
    let chore: Chore
    let isUploading: Bool
    let onSubmit: (PhotosPickerItem) -> Void

    @State private var selectedItem: PhotosPickerItem?


    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(chore.icon)
                .font(.largeTitle)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("Due: \(chore.dueDate, style: .date)")
                    Text("•")
                    Text("Reward: +\(chore.rewardCoins) stars")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                Text("Submit")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUploading)
            .onChange(of: selectedItem) { _, newItem in
                if let item = newItem {
                    onSubmit(item)
                }
            }
        }
        .appRowBackground()
    }
}

#if DEBUG
#Preview("Kid Chores") {
    let session = AppSessionViewModel.previewKidSession()
    let choresVM = ChoresViewModel(chores: Chore.previewList, availableKids: ["Kenny Kid"]) 
    let familyVM = FamilyViewModel(kids: [Kid(name: "Kenny Kid", coins: 12)])
    return NavigationStack { KidChoresView() }
        .environmentObject(session)
        .environmentObject(choresVM)
        .environmentObject(familyVM)
}
#endif
