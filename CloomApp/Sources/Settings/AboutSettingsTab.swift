import SwiftUI

struct AboutSettingsTab: View {
    @State private var updateChecker = UpdateChecker()

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            appIconAndVersion
            linksSection
            updateSection

            Spacer()

            footerText
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await updateChecker.checkForUpdates()
        }
    }

    // MARK: - Sections

    private var appIconAndVersion: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Cloom")
                .font(.title.bold())

            Text("Version \(updateChecker.currentVersion)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var linksSection: some View {
        HStack(spacing: 16) {
            Link(destination: URL(string: "https://github.com/iamsachin/cloom")!) {
                Label("GitHub", systemImage: "link")
            }

            Link(destination: URL(string: "https://github.com/iamsachin/cloom/issues")!) {
                Label("Report Issue", systemImage: "exclamationmark.bubble")
            }

            Link(destination: URL(string: "https://github.com/iamsachin/cloom/blob/main/LICENSE")!) {
                Label("MIT License", systemImage: "doc.text")
            }
        }
        .font(.callout)
    }

    private var updateSection: some View {
        VStack(spacing: 8) {
            if updateChecker.isChecking {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if updateChecker.updateAvailable, let latest = updateChecker.latestVersion {
                Label("Cloom v\(latest) is available", systemImage: "arrow.down.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.tint)

                if let url = updateChecker.downloadURL {
                    Link("Download Update", destination: url)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
            } else if let error = updateChecker.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("You're up to date", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Check for Updates") {
                Task { await updateChecker.checkForUpdates() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(updateChecker.isChecking)
        }
        .padding(.top, 4)
    }

    private var footerText: some View {
        Text("Open-source screen recorder for macOS")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}
