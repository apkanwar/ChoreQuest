import Foundation

enum DeepLink: Equatable {
    case submissionPhoto(submissionId: UUID, photoURL: URL)
}
