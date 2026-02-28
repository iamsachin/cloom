import Foundation
import GoogleSignIn
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "GoogleAuth")

@MainActor
@Observable
final class GoogleAuthService {
    static let shared = GoogleAuthService()

    private(set) var isSignedIn = false
    private(set) var userEmail: String?
    private(set) var userDisplayName: String?
    private(set) var authError: String?

    private var hasRestoredSession = false

    private init() {}

    // MARK: - Lazy Restore

    /// Call this before showing Cloud UI or triggering uploads.
    /// Only hits the Keychain once, on first call.
    func restoreSessionIfNeeded() {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true
        restoreSession()
    }

    // MARK: - Sign In

    func signIn() {
        guard GoogleAuthConfig.isConfigured else {
            authError = "OAuth Client ID not configured. Set it in Settings > Cloud."
            logger.error("Sign-in attempted without configured client ID")
            return
        }

        let config = GIDConfiguration(clientID: GoogleAuthConfig.clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
            authError = "No window available for sign-in. Open Settings first."
            logger.error("No presenting window available for Google Sign-In")
            return
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: window,
            hint: nil,
            additionalScopes: GoogleAuthConfig.scopes
        ) { [weak self] result, error in
            // Extract Sendable values before crossing isolation boundary
            let errorMsg = error?.localizedDescription
            let email = result?.user.profile?.email
            let name = result?.user.profile?.name
            let hasUser = result?.user != nil

            Task { @MainActor in
                guard let self else { return }
                if let errorMsg {
                    self.authError = errorMsg
                    logger.error("Google Sign-In failed: \(errorMsg)")
                    return
                }
                guard hasUser else {
                    self.authError = "Sign-in returned no user"
                    return
                }
                self.isSignedIn = true
                self.userEmail = email
                self.userDisplayName = name
                self.authError = nil
                logger.info("Signed in as \(email ?? "unknown")")
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        userDisplayName = nil
        authError = nil
        logger.info("Signed out of Google")
    }

    // MARK: - Restore Session

    func restoreSession() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            // Extract Sendable values before crossing isolation boundary
            let email = user?.profile?.email
            let name = user?.profile?.name
            let hasUser = user != nil
            let errorMsg = error?.localizedDescription

            Task { @MainActor in
                guard let self else { return }
                if hasUser {
                    self.isSignedIn = true
                    self.userEmail = email
                    self.userDisplayName = name
                    logger.info("Restored Google session for \(email ?? "unknown")")
                } else if let errorMsg {
                    logger.debug("No previous session to restore: \(errorMsg)")
                }
            }
        }
    }

    // MARK: - Token Refresh

    func refreshTokenIfNeeded() async -> String? {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            authError = "Not signed in"
            return nil
        }

        do {
            let user = try await currentUser.refreshTokensIfNeeded()
            return user.accessToken.tokenString
        } catch {
            authError = "Token refresh failed: \(error.localizedDescription)"
            logger.error("Token refresh failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Handle URL

    func handleURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

}
