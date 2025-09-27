import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AuthError: LocalizedError {
    case notConfigured
    case cancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase Auth is not configured. Install FirebaseAuth via Swift Package Manager and configure the app."
        case .cancelled:
            return "The sign-in request was cancelled."
        case .unknown:
            return "An unknown error occurred during authentication."
        }
    }
}

protocol AuthService {
    var currentUser: AuthenticatedUser? { get }
    func signInWithApple() async throws -> AuthenticatedUser
    func signInWithGoogle(presentingController: UIViewController?) async throws -> AuthenticatedUser
    func signOut() throws
}

struct AuthServiceFactory {
    static func make() -> AuthService {
        #if canImport(FirebaseAuth)
        return FirebaseAuthService()
        #else
        return MockAuthService()
        #endif
    }
}

#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import Security
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class FirebaseAuthService: NSObject, AuthService {
    private var currentNonce: String?

    var currentUser: AuthenticatedUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthenticatedUser(
            id: user.uid,
            displayName: user.displayName,
            email: user.email
        )
    }

    func signInWithApple() async throws -> AuthenticatedUser {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate

        try await delegate.perform(controller)

        guard
            let credential = delegate.credential,
            let identityToken = credential.identityToken,
            let tokenString = String(data: identityToken, encoding: .utf8),
            let nonce = currentNonce
        else {
            throw AuthError.unknown
        }

        let credentialFirebase = OAuthProvider.appleCredential(withIDToken: tokenString, rawNonce: nonce, fullName: delegate.credential?.fullName)

        let authResult = try await Auth.auth().signIn(with: credentialFirebase)
        return AuthenticatedUser(
            id: authResult.user.uid,
            displayName: authResult.user.displayName,
            email: authResult.user.email
        )
    }

    func signInWithGoogle(presentingController: UIViewController?) async throws -> AuthenticatedUser {
#if canImport(GoogleSignIn)
        guard let presentingController else { throw AuthError.notConfigured }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.notConfigured
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingController)
        guard let idToken = result.user.idToken?.tokenString else { throw AuthError.unknown }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)

        let authResult = try await Auth.auth().signIn(with: credential)
        return AuthenticatedUser(
            id: authResult.user.uid,
            displayName: authResult.user.displayName,
            email: authResult.user.email
        )
#else
        throw AuthError.notConfigured
#endif
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}

private extension FirebaseAuthService {
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<Void, Error>?
    fileprivate var credential: ASAuthorizationAppleIDCredential?

    func perform(_ controller: ASAuthorizationController) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        credential = authorization.credential as? ASAuthorizationAppleIDCredential
        continuation?.resume(returning: ())
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        // Prefer the current key window if available.
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        if let keyWindow = windowScenes
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return keyWindow
        }

        // If no key window is available, return any existing window from any connected scene.
        if let anyWindow = windowScenes
            .flatMap({ $0.windows })
            .first {
            return anyWindow
        }

        // Fallback: create a window anchored to a foreground-active scene.
        if let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) {
            return UIWindow(windowScene: activeScene)
        }

        // Fallback: create a window for any available scene.
        if let anyScene = windowScenes.first {
            return UIWindow(windowScene: anyScene)
        }

        // Ultimate fallback: If no scenes are available, fail fast on iOS 26+ where unattached windows are not supported.
        // On earlier iOS versions, fall back to an unattached window to satisfy the anchor requirement.
        if #available(iOS 26, *) {
            preconditionFailure("No UIWindowScene available to provide a presentation anchor for ASAuthorizationController.")
        } else {
            return UIWindow(frame: .zero)
        }

        #else
        return ASPresentationAnchor()
        #endif
    }
}

#else

final class FirebaseAuthService: AuthService {
    var currentUser: AuthenticatedUser? { nil }

    func signInWithApple() async throws -> AuthenticatedUser {
        throw AuthError.notConfigured
    }

    func signInWithGoogle(presentingController: UIViewController?) async throws -> AuthenticatedUser {
        throw AuthError.notConfigured
    }

    func signOut() throws {
        throw AuthError.notConfigured
    }
}

#endif

final class MockAuthService: AuthService {
    private(set) var currentUser: AuthenticatedUser?

    func signInWithApple() async throws -> AuthenticatedUser {
        let user = AuthenticatedUser(id: UUID().uuidString, displayName: "Apple Tester", email: "test@example.com")
        currentUser = user
        return user
    }

    func signInWithGoogle(presentingController: UIViewController?) async throws -> AuthenticatedUser {
        let user = AuthenticatedUser(id: UUID().uuidString, displayName: "Google Tester", email: "tester@example.com")
        currentUser = user
        return user
    }

    func signOut() throws {
        currentUser = nil
    }
}

