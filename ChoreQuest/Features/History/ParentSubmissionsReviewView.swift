import SwiftUI

struct ParentSubmissionsReviewView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    @State private var submissions: [Submission] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(submissions) { sub in
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            if let urlString = sub.photoURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(10)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                    Image(systemName: sub.type == .chore ? "photo" : "gift")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 80, height: 80)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(sub.displayTitle).font(.headline)
                                    Spacer()
                                    Text(sub.status.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .foregroundStyle(statusColor(for: sub.status))
                                        .background(statusColor(for: sub.status).opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                Text("\(sub.kidName) • \(sub.createdAt.formatted(date: .numeric, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Label(sub.type.displayName, systemImage: sub.type == .chore ? "checkmark.seal" : "gift")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let delta = sub.pointsDeltaOnApproval {
                                    Text(delta >= 0 ? "+\(delta) stars on approval" : "\(delta) stars on approval")
                                        .font(.caption)
                                        .foregroundStyle(delta >= 0 ? Color.green : Color.red)
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
                                if sub.status == .pending {
                                    HStack {
                                        Button(role: .destructive) { reject(sub) } label: {
                                            Label("Reject", systemImage: "xmark.circle")
                                        }
                                        .buttonStyle(.bordered)

                                        Spacer()

                                        Button { approve(sub) } label: {
                                            Label("Approve", systemImage: "checkmark.circle")
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView("Loading...") }
                else if submissions.isEmpty { ContentUnavailableView("No submissions", systemImage: "photo") }
            }
            .navigationTitle("Submissions")
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
}

private extension ParentSubmissionsReviewView {
    func reload() async {
        await MainActor.run { isLoading = true }
        let list = await session.fetchSubmissions()
        await MainActor.run {
            self.submissions = list
            self.isLoading = false
        }
    }

    func approve(_ sub: Submission) {
        Task {
            await session.approveSubmission(sub)
            await reload()
        }
    }

    func reject(_ sub: Submission) {
        Task {
            await session.rejectSubmission(sub)
            await reload()
        }
    }

    private func statusColor(for status: SubmissionStatus) -> Color {
        switch status {
        case .pending: return .yellow
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

#if DEBUG
#Preview("Parent Submissions Review") {
    let session = AppSessionViewModel.previewParentSession()
    return ParentSubmissionsReviewView()
        .environmentObject(session)
}
#endif
