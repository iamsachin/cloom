import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissionChecker: PermissionChecker
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("showPostOnboardingHint") private var showPostOnboardingHint: Bool = false

    private var requiredPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { !$0.isOptional }
    }

    private var optionalPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { $0.isOptional }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .frame(width: 72, height: 72)

                Text("Welcome to Cloom")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Grant permissions to start recording, and optionally set up AI features.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            // Two-column layout
            HStack(alignment: .top, spacing: 0) {
                // Left column — Required permissions
                VStack(alignment: .leading, spacing: 0) {
                    Text("Required")
                        .font(.headline)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)

                    Form {
                        ForEach(requiredPermissions) { kind in
                            permissionRow(for: kind)
                        }
                    }
                    .formStyle(.grouped)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .padding(.vertical, 16)

                // Right column — Optional (Accessibility + AI) + CTA
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text("Optional")
                                .font(.headline)
                        }
                        .padding(.bottom, 8)
                        .padding(.horizontal, 4)

                        Form {
                            ForEach(optionalPermissions) { kind in
                                permissionRow(for: kind)
                            }

                            Section {
                                APIKeyInputView()
                            } header: {
                                Text("AI Features")
                            } footer: {
                                Text("Enable AI-powered transcription, summaries, and chapter detection. You can add this later in Settings \u{203A} AI.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .formStyle(.grouped)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            // Footer CTA
            VStack(spacing: 6) {
                Divider()
                    .padding(.bottom, 4)

                Button {
                    hasCompletedOnboarding = true
                    showPostOnboardingHint = true
                    permissionChecker.stopPolling()
                    dismissWindow(id: "onboarding")
                } label: {
                    Text("Let's Record!")
                        .font(.headline)
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!permissionChecker.requiredGranted)
                .tint(permissionChecker.requiredGranted ? .accentColor : .gray)
                .scaleEffect(permissionChecker.requiredGranted ? 1.0 : 0.96)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: permissionChecker.requiredGranted)

                if !permissionChecker.requiredGranted {
                    Text("Grant the required permissions to continue")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(width: 820, height: 620)
        .onAppear {
            if !hasCompletedOnboarding && permissionChecker.allGranted {
                Task { @MainActor in
                    hasCompletedOnboarding = true
                    dismissWindow(id: "onboarding")
                }
                return
            }
            permissionChecker.startPolling()
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

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.icon)
                .font(.title2)
                .foregroundStyle(granted ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.displayName)
                    .font(.headline)

                Text(kind.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, 2)
            } else {
                Button("Grant") {
                    permissionChecker.requestPermission(kind)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(granted ? Color.permissionGrantedBackground : .clear)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: granted)
    }
}
