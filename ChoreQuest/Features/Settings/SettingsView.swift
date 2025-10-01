import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayNameDraft: String = ""
    @State private var familyNameDraft: String = ""
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    @State private var latestKidInviteCode: String?
    @State private var latestParentInviteCode: String?
    
    @State private var showLeaveAlert = false
    @State private var leaveWarningMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                familySection
                if session.currentFamily != nil && session.profile?.role == .parent {
                    invitesSection
                }
                actionsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                syncDrafts()
                Task {
                    if session.currentFamily != nil {
                        await refreshLatestInvite(role: .kid)
                        await refreshLatestInvite(role: .parent)
                    }
                }
            }
            .onChange(of: session.profile) { syncDrafts() }
            .onChange(of: session.currentFamily) { syncDrafts() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
                if hasUnsavedChanges {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { performSave() }
                    }
                }
            }
            .overlay(alignment: .top) {
                if showToast {
                    toastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding()
                }
            }
            .alert("Leave family?", isPresented: $showLeaveAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Leave", role: .destructive) {
                    session.leaveCurrentFamily()
                }
            } message: {
                Text(leaveWarningMessage)
            }
        }
    }

}

private extension SettingsView {
    var accountSection: some View {
        Section("Account") {
            if session.profile != nil {
                LabeledContent("Name") {
                    TextField("Display name", text: $displayNameDraft)
                        .textInputAutocapitalization(.words)
                        .multilineTextAlignment(.trailing)
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
                    if session.profile?.role == .parent {
                        TextField("Family name", text: $familyNameDraft)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(family.name)
                    }
                }
                Button(role: .destructive) {
                    leaveFamilyTapped()
                } label: {
                    Text("Leave Current Family")
                }
            } else {
                Text("You aren’t part of a family yet.")
                    .foregroundStyle(.secondary)
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

    var invitesSection: some View {
        Section("Invites") {
            // Kid invite row
            HStack {
                Button {
                    Task { await createInvite(role: .kid) }
                } label: {
                    Label("Create Kid Invite", systemImage: "person.2.badge.key")
                }
                Spacer()
                if let code = latestKidInviteCode {
                    Text(code)
                        .font(.monospaced(.body)())
                        .onTapGesture {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            #endif
                            toastMessage = "Copied"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                            }
                        }
                }
            }

            // Parent invite row
            HStack {
                Button {
                    Task { await createInvite(role: .parent) }
                } label: {
                    Label("Create Parent Invite", systemImage: "person.badge.key")
                }
                Spacer()
                if let code = latestParentInviteCode {
                    Text(code)
                        .font(.monospaced(.body)())
                        .onTapGesture {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            #endif
                            toastMessage = "Copied"
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                showToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                            }
                        }
                }
            }
        }
    }
}

private extension SettingsView {
    var hasUnsavedChanges: Bool {
        let nameChanged: Bool = {
            guard let profile = session.profile else { return false }
            return displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines) != profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let familyChanged: Bool = {
            guard let family = session.currentFamily else { return false }
            return familyNameDraft.trimmingCharacters(in: .whitespacesAndNewlines) != family.name.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        return nameChanged || familyChanged
    }

    func syncDrafts() {
        if let profile = session.profile {
            if displayNameDraft.isEmpty || displayNameDraft == "" || displayNameDraft == profile.displayName {
                displayNameDraft = profile.displayName
            }
        }
        if let family = session.currentFamily {
            if familyNameDraft.isEmpty || familyNameDraft == "" || familyNameDraft == family.name {
                familyNameDraft = family.name
            }
        }
    }

    func performSave() {
        var didRequestSave = false

        let trimmedDisplay = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let profile = session.profile, trimmedDisplay != profile.displayName {
            session.updateDisplayName(trimmedDisplay)
            didRequestSave = true
        }
        let trimmedFamily = familyNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let family = session.currentFamily, trimmedFamily != family.name, session.profile?.role == .parent {
            session.updateFamilyName(trimmedFamily)
            didRequestSave = true
        }
        if didRequestSave {
            showConfirmation("Saved")
        }
    }

    var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastMessage)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 4)
    }

    func showConfirmation(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showToast = false
            }
        }
    }

    func createInvite(role: UserRole) async {
        guard let familyId = session.currentFamily?.id else { return }
        do {
            let invite = try await sessionCreateInvite(familyId: familyId, role: role)
            await MainActor.run {
                switch role {
                case .kid: latestKidInviteCode = invite.code
                case .parent: latestParentInviteCode = invite.code
                }
                showConfirmation("Invite created")
            }
        } catch {
            await MainActor.run { toastMessage = error.localizedDescription; showToast = true }
        }
    }
    
    func refreshLatestInvite(role: UserRole) async {
        guard let familyId = session.currentFamily?.id else { return }
        do {
            let invite = try await sessionFetchLatestInviteProxy(familyId: familyId, role: role)
            await MainActor.run {
                switch role {
                case .kid: latestKidInviteCode = invite?.code
                case .parent: latestParentInviteCode = invite?.code
                }
            }
        } catch {
            await MainActor.run { toastMessage = error.localizedDescription; showToast = true }
        }
    }

    func sessionCreateInvite(familyId: String, role: UserRole) async throws -> FamilyInvite {
        try await sessionCreateInviteProxy(familyId: familyId, role: role)
    }
    
    func leaveFamilyTapped() {
        // Build warning message based on role
        var message = "Leaving this family will remove you from all associated data."
        if session.profile?.role == .parent {
            message += " If you are the only parent in this family, the family and its data will be deleted."
        }
        leaveWarningMessage = message
        showLeaveAlert = true
    }
}

#if DEBUG
#Preview("Settings – Parent") {
    let session = AppSessionViewModel.previewParentSession(familyName: "Williams")
    return SettingsView()
        .environmentObject(session)
}

#Preview("Settings – Kid") {
    let session = AppSessionViewModel.previewKidSession(familyName: "Williams")
    return SettingsView()
        .environmentObject(session)
}
#endif

