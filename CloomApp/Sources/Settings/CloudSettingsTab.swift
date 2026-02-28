import SwiftUI

struct CloudSettingsTab: View {
    private var authService = GoogleAuthService.shared

    var body: some View {
        Form {
            Section("Google Drive") {
                if authService.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }

                if let error = authService.authError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            authService.restoreSessionIfNeeded()
        }
    }

    @ViewBuilder
    private var signedInView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let name = authService.userDisplayName {
                    Text(name)
                        .font(.body.weight(.medium))
                }
                if let email = authService.userEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Disconnect") {
                authService.signOut()
            }
        }
    }

    @ViewBuilder
    private var signedOutView: some View {
        HStack {
            Text("Not connected")
                .foregroundStyle(.secondary)

            Spacer()

            Button("Connect Google Account") {
                authService.signIn()
            }
            .disabled(!GoogleAuthConfig.isConfigured)
        }

        if !GoogleAuthConfig.isConfigured {
            Text("Google Drive is not configured for this build.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
