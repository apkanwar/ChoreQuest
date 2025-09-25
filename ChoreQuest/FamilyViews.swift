import SwiftUI

// MARK: - Family Home (from screenshot)
struct FamilyHomeView: View {
    @State private var kids: [Kid] = [
        .init(name: "Akam", color: .pink, coins: 45),
        .init(name: "Ashley", color: .yellow, coins: 15),
        .init(name: "Sunny", color: .green, coins: 120)
    ]
    @State private var path = NavigationPath()

    // Responsive width for iPad/macOS
    private var maxContentWidth: CGFloat { 640 }
    private let headerHeight: CGFloat = 320

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .top) {
                headerView

                ScrollView(.vertical) {
                    Color.clear.frame(height: headerHeight)
                    content
                }
                .zIndex(0)
            }
            .background(
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .navigationDestination(for: Kid.self) { kid in
                KidDetailView(kid: kid)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            KidsCard(kids: $kids, onOpen: { kid in
                path.append(kid)
            })
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }
}

private extension FamilyHomeView {
    var headerView: some View {
        HeaderCard()
            .ignoresSafeArea(edges: .top)
            .frame(height: headerHeight)
            .zIndex(1000)
    }
}

struct KidsCard: View {
    @Binding var kids: [Kid]
    var onOpen: (Kid) -> Void
    @State private var showingAddKid = false
    @State private var selectedKid: Kid?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Kids")
                    .font(.title3.bold())
                Spacer()
                Button {
                    showingAddKid = true
                } label: {
                    Label("Add Kid", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingAddKid) {
                    AddKidSheet(kids: $kids)
                }
            }
            .padding(.bottom, 4)

            ForEach(kids) { kid in
                Button {
                    selectedKid = kid
                } label: {
                    KidRow(kid: kid)
                }
                .buttonStyle(.plain)
            }
            .sheet(item: $selectedKid) { kid in
                KidActionSheet(
                    kid: kid,
                    onOpen: {
                        onOpen(kid)
                        selectedKid = nil
                    },
                    onDelete: {
                        deleteKid(kid)
                        selectedKid = nil
                    }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
                )
        )
        .background(
            // Subtle glass on capable OS versions
            Group {
                if #available(iOS 18.0, macOS 15.0, *) {
                    Color.clear.glassEffect()
                }
            }
        )
    }

    private func deleteKid(_ kid: Kid) {
        kids.removeAll { $0.id == kid.id }
    }
}

struct KidRow: View {
    let kid: Kid
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let bgTint = Color.blue.opacity(scheme == .dark ? 0.14 : 0.08)

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
}

struct Kid: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var color: Color
    var coins: Int

    var initial: String { String(name.prefix(1)).uppercased() }
}

struct AddKidSheet: View {
    @Binding var kids: [Kid]
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    private let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Kid's name", text: $name)
                    #if os(iOS)
                        .textInputAutocapitalization(.words)
                    #endif
                }
            }
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let color = palette.randomElement() ?? .blue
        let newKid = Kid(name: trimmed, color: color, coins: 0)
        kids.append(newKid)
        dismiss()
    }
}

struct KidDetailView: View {
    let kid: Kid
    @State private var assignedChores: [String] = ["Make bed", "Take out trash"]
    @State private var completedChores: [String] = ["Brush teeth"]
    @State private var overdueChores: [String] = []
    @State private var pendingRewards: [String] = ["Ice cream voucher"]

    var body: some View {
        List {
            Section("Assign Chores") {
                Button("Assign a new chore") {
                    // Hook up to your chore assignment flow here
                }
            }

            if !assignedChores.isEmpty {
                Section("Assigned") {
                    ForEach(assignedChores, id: \.self) { Text($0) }
                }
            }

            if !completedChores.isEmpty {
                Section("Completed") {
                    ForEach(completedChores, id: \.self) { Text($0) }
                }
            }

            if !overdueChores.isEmpty {
                Section("Overdue") {
                    ForEach(overdueChores, id: \.self) { Text($0) }
                }
            }

            if !pendingRewards.isEmpty {
                Section("Pending Rewards") {
                    ForEach(pendingRewards, id: \.self) { Text($0) }
                }
            }
        }
        .navigationTitle(kid.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct KidActionSheet: View {
    let kid: Kid
    let onOpen: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmDelete = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(kid.color.opacity(0.3))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Text(kid.initial)
                                .font(.headline.bold())
                        )
                    VStack(alignment: .leading) {
                        Text(kid.name).font(.title3.bold())
                        Text("\(kid.coins) coins saved").foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top)

                VStack(spacing: 12) {
                    Button {
                        onOpen()
                        dismiss()
                    } label: {
                        Label("Open Profile", systemImage: "chevron.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showConfirmDelete = true
                    } label: {
                        Label("Delete Kid", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .confirmationDialog("Delete \(kid.name)?", isPresented: $showConfirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will remove the child and their local data from this device.")
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Kid Options")
            .navigationBarTitleDisplayMode(.inline)
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }
}


#if DEBUG
#Preview("Family Home") {
    FamilyHomeView()
}
#endif
