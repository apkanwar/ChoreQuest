import SwiftUI

struct ParentHistoryView: View {
    @EnvironmentObject private var session: AppSessionViewModel
    @EnvironmentObject private var familyVM: FamilyViewModel

    @State private var entries: [HistoryEntry] = []
    @State private var selectedType: HistoryType? = nil
    @State private var selectedKid: String = "Child"
    @State private var isLoading = false
    @State private var selectedPage: Int = 0

    @State private var submissions: [Submission] = []

    @State private var selectedPhotoURL: URL?
    @State private var isShowingPhoto = false
    @State private var entryPendingReversal: HistoryEntry?
    @State private var showReversalAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private let isPreview: Bool

    init(
        previewEntries: [HistoryEntry] = [],
        previewSubmissions: [Submission] = [],
        selectedPage: Int = 0,
        enablePreviewMode: Bool = false
    ) {
        self.isPreview = enablePreviewMode
        _entries = State(initialValue: previewEntries)
        _submissions = State(initialValue: previewSubmissions)
        _selectedPage = State(initialValue: selectedPage)
    }

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
                isPresented: errorBinding
            ) {
                Button("OK", role: .cancel) { session.errorMessage = nil }
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
            .alert("Reverse entry?", isPresented: $showReversalAlert) {
                Button("No", role: .cancel) { entryPendingReversal = nil }
                Button("Yes") {
                    guard let entry = entryPendingReversal else { return }
                    let delta = -entry.amount
                    Task {
                        let success = await session.reverseHistoryEntry(entry)
                        if success {
                            await reloadAll()
                            await MainActor.run {
                                toastMessage = reversalToastMessage(for: entry.kidName, delta: delta)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showToast = true }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                            }
                        }
                    }
                    entryPendingReversal = nil
                }
            } message: {
                Text("Are you sure you want to reverse this history entry?")
            }
            .task { if !isPreview { await reloadAll() } }
            .refreshable { if !isPreview { await reloadAll() } }
            .overlay(alignment: .top) {
                if showToast {
                    toastView
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding()
                }
            }
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
                                if let urlString = sub.photoURL, let url = URL(string: urlString) {
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
                            HistoryEntryRowView(
                                entry: entry,
                                onTapPhoto: {
                                    if let urlString = entry.photoURL, let url = URL(string: urlString) {
                                        selectedPhotoURL = url
                                        isShowingPhoto = true
                                    }
                                },
                                onReversePenalty: canReverse(entry) ? {
                                    entryPendingReversal = entry
                                    showReversalAlert = true
                                } : nil
                            )
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )
    }

    func canReverse(_ entry: HistoryEntry) -> Bool {
        guard session.profile?.role == .parent else { return false }
        guard !entry.isReversed else { return false }
        switch entry.type {
        case .choreCompleted, .rewardRedeemed:
            if let result = entry.result {
                return result != .pending
            }
            return true
        case .choreMissed:
            return true
        case .penaltyReversed:
            return false
        }
    }

    func reversalToastMessage(for kidName: String, delta: Int) -> String {
        if delta > 0 {
            return "Gave back \(delta) stars to \(kidName)"
        } else if delta < 0 {
            return "Removed \(abs(delta)) stars from \(kidName)"
        } else {
            return "Reversed entry for \(kidName)"
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

    func fetchSubmissions() async -> [Submission] {
        await session.fetchSubmissions()
    }

    func approve(_ sub: Submission) {
        Task {
            await session.approveSubmission(sub)
            await reloadAll()
        }
    }

    func reject(_ sub: Submission) {
        Task {
            await session.rejectSubmission(sub)
            await reloadAll()
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
}

private struct SubmissionRowView: View {
    let sub: Submission
    let onApprove: () -> Void
    let onReject: () -> Void
    let onTapPhoto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                submissionMedia
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(sub.displayTitle)
                            .font(.headline)
                        Spacer()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Label(sub.kidName, systemImage: "person")
                        Label(sub.createdAt.formatted(date: .numeric, time: .shortened), systemImage: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label(sub.type.displayName, systemImage: sub.type == .chore ? "checkmark.seal" : "gift")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                        if let delta = sub.pointsDeltaOnApproval {
                            Label(delta >= 0 ? "+\(delta)" : "\(delta)", systemImage: "star.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill((delta >= 0 ? Color.green : Color.red).opacity(0.25)))
                        }
                    }
                    if let reviewer = sub.reviewerName, let reviewedAt = sub.reviewedAt {
                        Text("Reviewed by \(reviewer) • \(reviewedAt.formatted(date: .numeric, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let note = sub.decisionNote, !note.isEmpty {
                        Text("Note: \(note)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
        .padding(8)
        .appRowBackground(color: Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(statusColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard sub.hasPhoto else { return }
            onTapPhoto()
        }
    }

    @ViewBuilder
    private var submissionMedia: some View {
        if let urlString = sub.photoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 64, height: 64)
            .clipped()
            .cornerRadius(8)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                if sub.type == .chore {
                    Image(systemName: "photo")
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("🎁")
                        .font(.title2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(width: 64, height: 64)
        }
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
    var onReversePenalty: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entryIcon)
                Text(entry.title)
                    .font(.headline)
                Spacer()
                amountBadge
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(entry.kidName, systemImage: "person")
                Label(formattedDate(entry.timestamp), systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            if let result = entry.result {
                Text(resultText(result))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(resultColor(result).opacity(0.18))
                    .foregroundStyle(resultColor(result))
                    .clipShape(Capsule())
            }
            if entry.isReversed {
                Text("Reversed")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.18))
                    .foregroundStyle(Color.blue)
                    .clipShape(Capsule())
            }
            if let onReversePenalty, !entry.isReversed {
                HStack {
                    Button(action: onReversePenalty) {
                        Label("Give Back", systemImage: "arrow.uturn.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(8)
        .appRowBackground(color: Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard entry.photoURL != nil else { return }
            onTapPhoto()
        }
    }

    private func resultColor(_ result: SubmissionStatus) -> Color {
        switch result {
        case .pending: return .yellow
        case .approved: return .green
        case .rejected: return .red
        }
    }
    
    private func resultText(_ result: SubmissionStatus) -> String {
        switch result {
        case .approved:
            return "Approved by \(entry.decidedByName ?? "Parent")"
        case .rejected:
            return "Rejected by \(entry.decidedByName ?? "Parent")"
        case .pending:
            return "Pending"
        }
    }

    private var entryIcon: String {
        switch entry.type {
        case .choreCompleted: return "✅"
        case .choreMissed: return "⚠️"
        case .rewardRedeemed: return "🎁"
        case .penaltyReversed: return "↩️"
        }
    }

    private var amountBadge: some View {
        let isPositive = entry.amount >= 0
        return Label(isPositive ? "+\(entry.amount)" : "\(entry.amount)", systemImage: "star.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill((isPositive ? Color.green : Color.red).opacity(0.25)))
    }
    
    private var borderColor: Color {
        if let result = entry.result {
            return resultColor(result)
        } else {
            return entry.amount >= 0 ? .green : .red
        }
    }

    private func formattedDate(_ date: Date) -> String {
        return HistoryEntryRowView.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM dd, yyyy, h:mm a"
        return df
    }()
}
