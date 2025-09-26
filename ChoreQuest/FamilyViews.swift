import SwiftUI

// MARK: - Family Home (from screenshot)
struct FamilyHomeView: View {
    @State private var kids: [Kid] = [
        .init(name: "Akam", color: .pink, coins: 45),
        .init(name: "Ashley", color: .yellow, coins: 15),
        .init(name: "Sunny", color: .green, coins: 120)
    ]
    @State private var isPresentingAddKid = false
    @State private var selectedKidForProfile: Kid?

    // Responsive width for iPad/macOS
    private var maxContentWidth: CGFloat { 640 }
    private let headerHeight: CGFloat = 200
    private let headerTopContentOffset: CGFloat = 32

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                headerView

                ScrollView(.vertical) {
                    Color.clear.frame(height: headerHeight - headerTopContentOffset)
                    content
                }
                .zIndex(0)
            }
            .overlay(alignment: .top) {
                HStack {
                    Spacer()
                    Button {
                        isPresentingAddKid = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .accessibilityLabel("Add Kid")
                    #if os(iOS)
                    .hoverEffect(.lift)
                    #endif
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal)
                .padding(.vertical, 100)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
            )
            .sheet(isPresented: $isPresentingAddKid) {
                AddKidSheet(kids: $kids)
            }
            .sheet(item: $selectedKidForProfile) { kid in
                EditKidSheet(
                    kid: kid,
                    onSave: { updated in
                        if let idx = kids.firstIndex(where: { $0.id == updated.id }) {
                            kids[idx] = updated
                        }
                        selectedKidForProfile = nil
                    },
                    onDelete: {
                        kids.removeAll { $0.id == kid.id }
                        selectedKidForProfile = nil
                    }
                )
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // TODO: Show notifications
                    } label: {
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Notifications")

                    Button {
                        // TODO: Open settings
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            KidsCard(kids: $kids, onOpen: { kid in
                selectedKidForProfile = kid
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Kids")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.bottom, 4)

            ForEach(kids) { kid in
                Button {
                    onOpen(kid)
                } label: {
                    KidRow(kid: kid)
                }
                .buttonStyle(.plain)
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

struct EditKidSheet: View {
    let kid: Kid
    let onSave: (Kid) -> Void
    let onDelete: (() -> Void)?
    @EnvironmentObject var choresViewModel: ChoresViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: Color

    private let palette: [Color] = [.pink, .yellow, .green, .orange, .purple, .teal, .blue]

    @State private var showDeleteConfirmation = false

    init(kid: Kid, onSave: @escaping (Kid) -> Void, onDelete: (() -> Void)? = nil) {
        self.kid = kid
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: kid.name)
        _color = State(initialValue: kid.color)
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                assignChoresSection
                assignedChoresSection
                savingsSection
                if onDelete != nil {
                    deleteSection
                }
            }
            .navigationTitle("Edit Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .confirmationDialog("Delete \(kid.name)?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteKid()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the child and their local data from this device.")
            }
        }
    }
}

private extension EditKidSheet {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !trimmedName.isEmpty
    }

    var detailsSection: some View {
        Section("Details") {
            TextField("Kid's name", text: $name)
            #if os(iOS)
                .textInputAutocapitalization(.words)
            #endif

            colorPicker
        }
    }

    var colorPicker: some View {
        ColorPicker("Color", selection: $color, supportsOpacity: false)
    }

    var savingsSection: some View {
        Section("Savings") {
            LabeledContent("Coins") {
                Text("\(kid.coins) coins")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var unassignedChores: [Chore] {
        choresViewModel.chores.filter { $0.assignedTo.isEmpty }
    }

    var kidChores: [Chore] {
        choresViewModel.chores.filter { $0.assignedTo.contains(kid.name) }
    }

    var assignChoresSection: some View {
        Section("Assign Chores") {
            if unassignedChores.isEmpty {
                Text("No unassigned chores")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(unassignedChores) { chore in
                    HStack {
                        Text("\(chore.icon) \(chore.name)")
                        Spacer()
                        Button {
                            assign(chore)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.green)
                                .opacity(0.75)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Assign")
                    }
                }
            }
        }
    }

    var assignedChoresSection: some View {
        Section("Assigned to \(kid.name)") {
            if kidChores.isEmpty {
                Text("No chores assigned yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(kidChores) { chore in
                    HStack {
                        Text("\(chore.icon) \(chore.name)")
                        Spacer()
                        Button {
                            unassign(chore)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.red)
                                .opacity(0.75)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove")
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            unassign(chore)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    func assign(_ chore: Chore) {
        var updated = chore
        updated.assignedTo = [kid.name]
        choresViewModel.update(updated)
    }

    func unassign(_ chore: Chore) {
        var updated = chore
        updated.assignedTo = []
        choresViewModel.update(updated)
    }

    func save() {
        guard canSave else { return }
        let oldName = kid.name
        var updated = kid
        updated.name = trimmedName
        updated.color = color
        onSave(updated)

        if oldName != updated.name {
            for var chore in choresViewModel.chores where chore.assignedTo.contains(oldName) {
                chore.assignedTo = chore.assignedTo.map { $0 == oldName ? updated.name : $0 }
                choresViewModel.update(chore)
            }
        }
        dismiss()
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Kid", systemImage: "trash")
            }
        }
    }

    func deleteKid() {
        guard let onDelete else { return }
        onDelete()
        dismiss()
    }

    @ToolbarContentBuilder
    var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .disabled(!canSave)
        }
    }
}

struct KidDetailView: View {
    let kid: Kid
    let onDelete: () -> Void
    let onUpdate: (Kid) -> Void
    @State private var isPresentingEdit = false
    @State private var assignedChores: [String] = ["Make bed", "Take out trash"]
    @State private var completedChores: [String] = ["Brush teeth"]
    @State private var overdueChores: [String] = []
    @State private var pendingRewards: [String] = ["Ice cream voucher"]
    @State private var showConfirmDelete = false

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

            Section {
                Button(role: .destructive) {
                    showConfirmDelete = true
                } label: {
                    Text("Delete Kid")
                }
            }
        }
        .navigationTitle(kid.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete \(kid.name)?", isPresented: $showConfirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the child and their local data from this device.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isPresentingEdit = true }
            }
        }
        .sheet(isPresented: $isPresentingEdit) {
            EditKidSheet(
                kid: kid,
                onSave: { updated in
                    onUpdate(updated)
                },
                onDelete: {
                    onDelete()
                }
            )
            #if os(iOS)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }
}


#if DEBUG
#Preview("Family Home") {
    ContentView()
}
#endif
