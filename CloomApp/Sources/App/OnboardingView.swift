import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissionChecker: PermissionChecker
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 80, height: 80)
                }

                Text("Welcome to Cloom")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Cloom needs a few permissions to record your screen, camera, and microphone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            .padding(.top, 8)

            // Permission rows
            Form {
                ForEach(PermissionKind.allCases) { kind in
                    permissionRow(for: kind)
                }
            }
            .formStyle(.grouped)

            // Footer
            Button("Get Started") {
                permissionChecker.stopPolling()
                dismissWindow(id: "onboarding")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!permissionChecker.allGranted)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .frame(width: 520, height: 560)
        .onAppear {
            if permissionChecker.allGranted {
                dismissWindow(id: "onboarding")
                return
            }
            permissionChecker.startPolling()
            // Bring window to front above other apps
            NSApp.activate()
            DispatchQueue.main.async {
                NSApp.windows
                    .first { $0.title == "Welcome to Cloom" }?
                    .orderFrontRegardless()
            }
        }
        .onDisappear {
            permissionChecker.stopPolling()
        }
        .animation(.easeInOut, value: permissionChecker.statuses.values.map { $0 })
    }

    @ViewBuilder
    private func permissionRow(for kind: PermissionKind) -> some View {
        let granted = permissionChecker.statuses[kind] == true

        HStack(spacing: 12) {
            Image(systemName: kind.icon)
                .font(.title2)
                .foregroundStyle(granted ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(kind.displayName)
                    .font(.headline)

                Text(kind.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button("Grant") {
                    permissionChecker.requestPermission(kind)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}
