import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateFamily = false
    @State private var showJoinFamily = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                familySection
                actionsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
            }
        }
        .sheet(isPresented: $showCreateFamily) {
            CreateFamilySheet { session.createFamily(named: $0) }
        }
        .sheet(isPresented: $showJoinFamily) {
            JoinFamilySheet { session.joinFamily(withCode: $0) }
        }
    }

}

private extension SettingsView {
    var accountSection: some View {
        Section("Account") {
            if let profile = session.profile {
                LabeledContent("Name") {
                    Text(profile.displayName)
                }
                if let email = session.userEmail {
                    LabeledContent("Email") {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var familySection: some View {
        Section("Family") {
            if let family = session.currentFamily {
                LabeledContent("Family Name") {
                    Text(family.name)
                }
                LabeledContent("Invite Code") {
                    Text(family.inviteCode)
                        .font(.monospaced(.body)())
                }
                Button("Create New Family") { showCreateFamily = true }
                Button("Join Different Family") { showJoinFamily = true }
            } else {
                Text("You aren’t part of a family yet.")
                    .foregroundStyle(.secondary)
                Button("Create Family") { showCreateFamily = true }
                Button("Join Family") { showJoinFamily = true }
            }
        }
    }

    var actionsSection: some View {
        Section {
            Button(role: .destructive, action: session.signOut) {
                Text("Log Out")
            }
        }
    }
}

#if DEBUG
#Preview("Settings") {
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
    return SettingsView()
        .environmentObject(session)
}
#endif
