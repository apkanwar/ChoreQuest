import SwiftUI

struct CreateFamilySheet: View {
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var familyName: String = ""
    @EnvironmentObject private var session: AppSessionViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Name") {
                    TextField("e.g., The Kanwar Crew", text: $familyName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Create Family")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onSubmit(familyName)
                        dismiss()
                    }
                    .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct JoinFamilySheet: View {
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode: String = ""
    @State private var showJoinWarning = false
    @EnvironmentObject private var session: AppSessionViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Code") {
                    TextField("Enter invite code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: joinCode) { _, newValue in
                            let upper = newValue.uppercased()
                            if upper != newValue {
                                joinCode = upper
                            }
                        }
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Join Family")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        if session.currentFamily != nil {
                            showJoinWarning = true
                        } else {
                            onSubmit(trimmed)
                            dismiss()
                        }
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .alert("Join another family?", isPresented: $showJoinWarning) {
                Button("Cancel", role: .cancel) {}
                Button("Join", role: .destructive) {
                    // Leave current family first (this will also delete it if this user is the last parent)
                    session.leaveCurrentFamily()
                    let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSubmit(trimmed)
                    dismiss()
                }
            } message: {
                Text(
                    "Joining another family will remove you from your current family." +
                    ((session.profile?.role == .parent) ? " If you are the only parent in your current family, the family will be deleted." : "")
                )
            }
        }
    }
}

#if DEBUG
#Preview("Create Family Sheet") {
    let familyVM = FamilyViewModel()
    let choresVM = ChoresViewModel()
    let rewardsVM = RewardsViewModel()
    let session = AppSessionViewModel(
        authService: MockAuthService(),
        firestoreService: MockFirestoreService.shared,
        storageService: MockStorageService(),
        familyViewModel: familyVM,
        choresViewModel: choresVM,
        rewardsViewModel: rewardsVM
    )
    return CreateFamilySheet { _ in }
        .environmentObject(session)
}

#Preview("Join Family Sheet") {
    let familyVM = FamilyViewModel()
    let choresVM = ChoresViewModel()
    let rewardsVM = RewardsViewModel()
    let session = AppSessionViewModel(
        authService: MockAuthService(),
        firestoreService: MockFirestoreService.shared,
        storageService: MockStorageService(),
        familyViewModel: familyVM,
        choresViewModel: choresVM,
        rewardsViewModel: rewardsVM
    )
    return JoinFamilySheet { _ in }
        .environmentObject(session)
}
#endif
