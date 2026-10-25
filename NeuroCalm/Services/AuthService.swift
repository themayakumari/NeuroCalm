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

    var isSignedIn: Bool { user != nil }
    var displayName: String? { user?.displayName }
    var uid: String? { user?.uid }
    /// A friendly name for team leaderboards.
    var friendlyName: String {
        if let name = user?.displayName, !name.isEmpty { return name }
        return "Me"
    }

    /// A nonce kept between starting the Apple request and receiving its result.
    private var currentNonce: String?

    private var authHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        user = Auth.auth().currentUser
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
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

    /// Validate a school code against Firestore, then sign the student in
    /// anonymously and tag the account with the school. Lets students without
    /// an Apple/Google account still use the app.
    func joinWithSchoolCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter your school code."
            return
        }
        isJoining = true
        errorMessage = nil
        Task { @MainActor in
            defer { isJoining = false }
            do {
                guard let school = try await SchoolService.findSchool(code: trimmed) else {
                    errorMessage = "We couldn't find that school code."
                    return
                }
                let result = try await Auth.auth().signInAnonymously()
                let change = result.user.createProfileChangeRequest()
                change.displayName = "Student · \(school.name)"
                try? await change.commitChanges()
                UserDefaults.standard.set(school.id, forKey: "schoolId")
                UserDefaults.standard.set(school.name, forKey: "schoolName")
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
