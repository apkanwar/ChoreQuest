import SwiftUI

struct ParentHistoryView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var entries: [HistoryEntry] = []
    @State private var selectedType: HistoryType? = nil
    @State private var selectedKid: String = "Child"
    @State private var isLoading = false
    @State private var selectedPage: Int = 0

    @State private var submissions: [ChoreSubmission] = []

    @State private var selectedPhotoURL: URL?
    @State private var isShowingPhoto = false

    var body: some View {
        NavigationStack {
            AppScreen(headerTopOffset: 0, allowsScroll: false) {
                VStack(spacing: AppSpacing.section) {
                    modePicker
                    TabView(selection: $selectedPage) {
                        submissionsSection.tag(0)
                        historySection.tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .alert(
                "Error",
                isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(session.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $isShowingPhoto) {
                NavigationStack {
                    VStack {
                        if let url = selectedPhotoURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .padding()
                        }
                    }
                    .navigationTitle("Submission Photo")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button("Close") { isShowingPhoto = false }
                        }
                    }
                }
            }
            .task { await reloadAll() }
            .refreshable { await reloadAll() }
        }
    }
}

private extension ParentHistoryView {
    var modePicker: some View {
        Picker("Mode", selection: $selectedPage) {
            Text("Submissions").tag(0)
            Text("History").tag(1)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    var submissionsSection: some View {
        if submissions.isEmpty {
            ContentUnavailableView("No submissions", systemImage: "photo")
                .frame(maxWidth: .infinity)
                .appCardStyle()
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.section) {
                    ForEach(submissions) { sub in
                        SubmissionRowView(
                            sub: sub,
                            onApprove: { approve(sub) },
                            onReject: { reject(sub) },
                            onTapPhoto: {
                                if let url = URL(string: sub.photoURL) {
                                    selectedPhotoURL = url
                                    isShowingPhoto = true
                                }
                            }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .appCardStyle()
        }
    }

    @ViewBuilder
    var historySection: some View {
        VStack(spacing: AppSpacing.section) {
            filters
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No history",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Try adjusting filters.")
                )
                .frame(maxWidth: .infinity)
                .appCardStyle()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.section) {
                        ForEach(filteredEntries) { entry in
                            HistoryEntryRowView(entry: entry) {
                                if let urlString = entry.photoURL, let url = URL(string: urlString) {
                                    selectedPhotoURL = url
                                    isShowingPhoto = true
                                }
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .appCardStyle()
            }
        }
    }

    var filters: some View {
        HStack(spacing: 12) {
            Picker("Type", selection: $selectedType) {
                Text("Type").tag(HistoryType?.none)
                Text("Chores").tag(Optional(HistoryType.choreCompleted))
                Text("Rewards").tag(Optional(HistoryType.rewardRedeemed))
            }
            .pickerStyle(.menu)
            .layoutPriority(1)

            Spacer(minLength: 12)

            let kidOptions: [String] = (["Child"] + Array(Set(familyVM.kids.map { $0.name } + entries.map { $0.kidName }))).sorted()
            Picker("Kid", selection: $selectedKid) {
                ForEach(kidOptions, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
        }
    }

    var filteredEntries: [HistoryEntry] {
        entries.filter { entry in
            let matchesType = selectedType.map { $0 == entry.type } ?? true
            let matchesKid = selectedKid == "Child" || entry.kidName == selectedKid
            return matchesType && matchesKid
        }
    }

    func reloadAll() async {
        await MainActor.run { isLoading = true }
        async let historyTask = session.fetchHistory()
        async let submissionsTask = fetchSubmissions()
        let (history, subs) = await (historyTask, submissionsTask)
        await MainActor.run {
            entries = history
            submissions = subs
            isLoading = false
        }
    }

    func fetchSubmissions() async -> [ChoreSubmission] {
        await session.fetchSubmissions()
    }

    func approve(_ sub: ChoreSubmission) {
        Task {
            await session.approveSubmission(sub)
            await reloadAll()
        }
    }

    func reject(_ sub: ChoreSubmission) {
        Task {
            await session.rejectSubmission(sub)
            await reloadAll()
        }
    }
}

private struct SubmissionRowView: View {
    let sub: ChoreSubmission
    let onApprove: () -> Void
    let onReject: () -> Void
    let onTapPhoto: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: sub.photoURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 64, height: 64)
            .clipped()
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(sub.choreName)
                        .font(.headline)
                    Spacer()
                    Text(sub.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .clipShape(Capsule())
                }
                Text("\(sub.kidName) • \(sub.submittedAt.formatted(date: .numeric, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reviewer = sub.reviewer, let reviewedAt = sub.reviewedAt {
                    Text("Reviewed by \(reviewer) • \(reviewedAt.formatted(date: .numeric, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let reason = sub.rejectionReason, !reason.isEmpty {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if sub.status == .pending {
                    HStack {
                        Button(role: .destructive, action: onReject) {
                            Label("Reject", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button(action: onApprove) {
                            Label("Approve", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .appRowBackground(color: Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapPhoto)
    }

    private var statusColor: Color {
        switch sub.status {
        case .pending: return .yellow
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

private struct HistoryEntryRowView: View {
    let entry: HistoryEntry
    let onTapPhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.type == .choreCompleted ? "✅" : "🎁")
                Text(entry.title)
                    .font(.headline)
                Spacer()
                Text(String(format: "%@%d", entry.amount >= 0 ? "+" : "", entry.amount))
                    .foregroundStyle(entry.amount >= 0 ? .green : .red)
                    .monospacedDigit()
            }
            Text("\(entry.kidName) • \(entry.timestamp.formatted(date: .numeric, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .appRowBackground(color: Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapPhoto)
    }
}

#if DEBUG
#Preview("Parent History") {
    let session = AppSessionViewModel.previewParentSession()
    let familyVM = FamilyViewModel(kids: [Kid(name: "Kenny Kid", coins: 12)])
    ParentHistoryView()
        .environmentObject(session)
        .environmentObject(familyVM)
}
#endif
