import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissionChecker: PermissionChecker
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("showPostOnboardingHint") private var showPostOnboardingHint: Bool = false
    @AppStorage(UserDefaultsKeys.hasSeenMenuBarHint) private var hasSeenMenuBarHint: Bool = false

    @State private var showMenuBarHint: Bool = false

    private var requiredPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { !$0.isOptional }
    }

    private var optionalPermissions: [PermissionKind] {
        PermissionKind.allCases.filter { $0.isOptional }
    }

    var body: some View {
        Group {
            if showMenuBarHint {
                MenuBarHintView(onDismiss: completeOnboarding)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                permissionsStep
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showMenuBarHint)
        .onAppear { handleAppear() }
        .onDisappear {
            permissionChecker.stopPolling()
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 20) {
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

            HStack(alignment: .top, spacing: 0) {
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

            VStack(spacing: 6) {
                Divider()
                    .padding(.bottom, 4)

                Button {
                    handleProceed()
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
        .animation(.easeInOut, value: permissionChecker.statuses.values.map { $0 })
    }

    private func handleProceed() {
        if hasSeenMenuBarHint {
            completeOnboarding()
        } else {
            showMenuBarHint = true
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        showPostOnboardingHint = true
        hasSeenMenuBarHint = true
        permissionChecker.stopPolling()
        scheduleWelcomeNotification()
        dismissWindow(id: "onboarding")
    }

    private func scheduleWelcomeNotification() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            NotificationService.post(
                title: "Cloom is ready",
                body: "Click the Cloom icon in your menu bar to start a recording."
            )
        }
    }

    private func handleAppear() {
        if !hasCompletedOnboarding && permissionChecker.allGranted {
            if hasSeenMenuBarHint {
                Task { @MainActor in
                    hasCompletedOnboarding = true
                    dismissWindow(id: "onboarding")
                }
                return
            }
            showMenuBarHint = true
        }
        permissionChecker.startPolling()
        NSApp.activate()
        DispatchQueue.main.async {
            NSApp.windows
                .first { $0.title == "Welcome to Cloom" }?
                .orderFrontRegardless()
        }
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
