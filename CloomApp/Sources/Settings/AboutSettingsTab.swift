import SwiftUI

struct AboutSettingsTab: View {
    @EnvironmentObject private var sparkleUpdater: SparkleUpdater

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
    }

    // MARK: - Sections

    private var appIconAndVersion: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("Cloom")
                .font(.title.bold())

            Text("Version \(currentVersion)")
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
        Button("Check for Updates...") {
            sparkleUpdater.checkForUpdates()
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(!sparkleUpdater.canCheckForUpdates)
        .padding(.top, 4)
    }

    private var footerText: some View {
        Text("Open-source screen recorder for macOS")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
