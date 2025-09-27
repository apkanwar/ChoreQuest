import SwiftUI

struct CreateFamilySheet: View {
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var familyName: String = ""

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Code") {
                    TextField("Enter invite code", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: joinCode) { newValue in
                            joinCode = newValue.uppercased()
                        }
                }
            }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        onSubmit(joinCode)
                        dismiss()
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }
}

#if DEBUG
#Preview("Create Family Sheet") {
    CreateFamilySheet { _ in }
}

#Preview("Join Family Sheet") {
    JoinFamilySheet { _ in }
}
#endif
