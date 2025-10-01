import SwiftUI

struct ParentSubmissionsReviewView: View {
    @EnvironmentObject private var session: AppSessionViewModel

    @State private var submissions: [ChoreSubmission] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(submissions) { sub in
                    Section {
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: URL(string: sub.photoURL)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(10)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(sub.choreName).font(.headline)
                                    Spacer()
                                    Text(sub.status.displayName)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(sub.status == .pending ? Color.yellow.opacity(0.2) : (sub.status == .approved ? Color.green.opacity(0.2) : Color.red.opacity(0.2)))
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

    func approve(_ sub: ChoreSubmission) {
        Task {
            await session.approveSubmission(sub)
            await reload()
        }
    }

    func reject(_ sub: ChoreSubmission) {
        Task {
            await session.rejectSubmission(sub)
            await reload()
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
