import Foundation

enum StorageError: LocalizedError {
    case notConfigured
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase Storage is not configured. Install FirebaseStorage via Swift Package Manager."
        case .unknown:
            return "An unknown storage error occurred."
        }
    }
}

protocol StorageService {
    func upload(data: Data, to path: String, contentType: String?) async throws -> URL
}

struct StorageServiceFactory {
    static func make() -> StorageService {
        #if canImport(FirebaseStorage)
        FirebaseStorageService()
        #else
        MockStorageService()
        #endif
    }
}

#if canImport(FirebaseStorage)
import FirebaseStorage

struct FirebaseStorageService: StorageService {
    private let storage = Storage.storage()

    func upload(data: Data, to path: String, contentType: String?) async throws -> URL {
        let reference = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        if let contentType { metadata.contentType = contentType }
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }
}
#else

struct FirebaseStorageService: StorageService {
    func upload(data: Data, to path: String, contentType: String?) async throws -> URL {
        throw StorageError.notConfigured
    }
}

#endif

struct MockStorageService: StorageService {
    func upload(data: Data, to path: String, contentType: String?) async throws -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(path)
        try? FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: tempURL)
        return tempURL
    }
}
