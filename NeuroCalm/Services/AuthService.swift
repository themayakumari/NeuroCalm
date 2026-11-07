//
//  AuthService.swift
//  NeuroCalm
//
//  Firebase-backed authentication. Owns the signed-in state the app reacts to
//  and implements Sign in with Apple (Google and school code come next).
//  Injected into the environment so any view can read `isSignedIn`.
//

import Foundation
import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var user: User?
    @Published var errorMessage: String?
    /// True while a school-code join is in flight (for the join UI).
    @Published var isJoining = false
    /// Set when a school code was linked to an already signed-in account.
    @Published var didLinkSchool = false

    var isSignedIn: Bool { user != nil }
    var displayName: String? { user?.displayName }
    var uid: String? { user?.uid }
    /// True when the account signs in with Apple (deleting it asks Apple to confirm).
    var usesAppleSignIn: Bool {
        user?.providerData.contains { $0.providerID == "apple.com" } ?? false
    }
    /// Signed in with a school code (no Apple or Google account).
    var isAnonymous: Bool { user?.isAnonymous ?? false }

    /// A nonce kept between starting the Apple request and receiving its result.
    private var currentNonce: String?

    /// Waits for the Apple sheet shown while deleting an account.
    private var appleReauthContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    private var authHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        user = Auth.auth().currentUser
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                let previous = self?.user?.uid
                self?.user = user
                if let uid = user?.uid, uid != previous {
                    // Bring the account's school onto this phone.
                    try? await SchoolService.restoreFromAccount(uid: uid)
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            // The school lives on the account; the next sign-in restores it.
            SchoolService.clearLocal()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete account

    /// Permanently delete the signed-in account: leave any team challenges,
    /// then delete the Firebase user. Apple accounts confirm with a fresh
    /// Apple sign-in so the app can also revoke its Apple access, and Google
    /// accounts sign in again if Firebase asks for a recent login.
    /// Local data is wiped separately by the caller.
    func deleteAccount(teamChallengeIds: [String]) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let providers = Set(user.providerData.map(\.providerID))

        if providers.contains("apple.com") {
            let credential = try await requestAppleReauthorization()
            guard
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let codeData = credential.authorizationCode,
                let authCode = String(data: codeData, encoding: .utf8)
            else {
                throw AccountDeletionError.appleCredentialUnreadable
            }
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken, rawNonce: nonce, fullName: nil
            )
            try await user.reauthenticate(with: firebaseCredential)
            try await leaveTeamChallenges(teamChallengeIds, uid: user.uid)
            try await SchoolService.removeFromAccount(uid: user.uid)
            try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
            try await user.delete()
        } else {
            try await leaveTeamChallenges(teamChallengeIds, uid: user.uid)
            try await SchoolService.removeFromAccount(uid: user.uid)
            do {
                try await user.delete()
            } catch let error as NSError where error.code == AuthErrorCode.requiresRecentLogin.rawValue
                        && providers.contains("google.com") {
                try await reauthenticateWithGoogle(user)
                try await user.delete()
            }
        }

        // Deleting already ends the session; signing out makes sure the app
        // returns to the login screen right away.
        try? Auth.auth().signOut()
        self.user = nil
        if providers.contains("google.com") {
            try? await GIDSignIn.sharedInstance.disconnect()
        }
        SchoolService.clearLocal()
    }

    /// Remove this member from every team challenge they joined, so their
    /// name and count don't stay on friends' leaderboards. Stops the deletion
    /// if the list can't be read, so nothing is left behind.
    private func leaveTeamChallenges(_ ids: [String], uid: String) async throws {
        // The account's list also covers challenges joined on another phone.
        let onAccount = try await TeamService.accountChallenges(uid: uid).map(\.id)
        for id in Set(ids + onAccount) {
            do {
                try await TeamService.leave(id: id, uid: uid)
            } catch TeamError.notFound {
                continue  // Already gone.
            }
        }
    }

    private func reauthenticateWithGoogle(_ user: User) async throws {
        guard let presenter = Self.topViewController() else {
            throw AccountDeletionError.cannotPresent
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AccountDeletionError.googleCredentialUnreadable
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken, accessToken: result.user.accessToken.tokenString
        )
        try await user.reauthenticate(with: credential)
    }

    /// Show the Apple sign-in sheet and wait for the new credential.
    private func requestAppleReauthorization() async throws -> ASAuthorizationAppleIDCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            appleReauthContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Sign in with Google

    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing Google client ID."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = Self.topViewController() else {
            errorMessage = "Couldn't present Google sign-in."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                guard
                    let idToken = result?.user.idToken?.tokenString,
                    let accessToken = result?.user.accessToken.tokenString
                else {
                    self?.errorMessage = "Couldn't read the Google account."
                    return
                }
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                do {
                    try await Auth.auth().signIn(with: credential)
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Join with a school code

    /// Validate a school code against Firestore, then save the school to the
    /// account. Signed out, this signs the student in anonymously first, so
    /// students without an Apple/Google account can still use the app.
    /// Signed in, it links the school to the current account.
    func joinWithSchoolCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your school code."
            return
        }
        isJoining = true
        didLinkSchool = false
        errorMessage = nil
        Task { @MainActor in
            defer { isJoining = false }
            do {
                guard let school = try await SchoolService.findSchool(code: trimmed) else {
                    errorMessage = "We couldn't find that school code."
                    return
                }
                if let current = Auth.auth().currentUser {
                    try await SchoolService.saveToAccount(school, uid: current.uid)
                    didLinkSchool = true
                    return
                }
                let result = try await Auth.auth().signInAnonymously()
                let change = result.user.createProfileChangeRequest()
                change.displayName = "Student · \(school.name)"
                try? await change.commitChanges()
                do {
                    try await SchoolService.saveToAccount(school, uid: result.user.uid)
                } catch {
                    // Still signed in; keep the school on this phone at least.
                    SchoolService.storeLocally(id: school.id, name: school.name)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// The frontmost view controller, used to present system sign-in UI.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    // MARK: - Sign in with Apple

    /// Configure the Apple ID request with a hashed nonce (required by Firebase).
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the result of the Apple authorization and sign in to Firebase.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Could not read the Apple credential."
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            Auth.auth().signIn(with: firebaseCredential) { [weak self] result, error in
                Task { @MainActor in
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    // Apple only sends the name on the very first sign-in — persist it.
                    if let fullName = credential.fullName,
                       let user = result?.user,
                       (user.displayName ?? "").isEmpty {
                        let name = [fullName.givenName, fullName.familyName]
                            .compactMap { $0 }.joined(separator: " ")
                        if !name.isEmpty {
                            let change = user.createProfileChangeRequest()
                            change.displayName = name
                            change.commitChanges(completion: nil)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AccountDeletionError: LocalizedError {
    case appleCredentialUnreadable
    case googleCredentialUnreadable
    case cannotPresent

    var errorDescription: String? {
        switch self {
        case .appleCredentialUnreadable:  return "Could not read the Apple credential."
        case .googleCredentialUnreadable: return "Couldn't read the Google account."
        case .cannotPresent:              return "Couldn't show the sign-in screen."
        }
    }
}

// MARK: - Apple sheet for account deletion

extension AuthService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        Task { @MainActor in
            if let credential {
                appleReauthContinuation?.resume(returning: credential)
            } else {
                appleReauthContinuation?.resume(throwing: AccountDeletionError.appleCredentialUnreadable)
            }
            appleReauthContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            appleReauthContinuation?.resume(throwing: error)
            appleReauthContinuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .keyWindow ?? ASPresentationAnchor()
        }
    }
}
