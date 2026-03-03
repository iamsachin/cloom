import Foundation

/// Checks GitHub Releases API for newer versions of Cloom.
@MainActor
@Observable
final class UpdateChecker {
    private(set) var latestVersion: String?
    private(set) var downloadURL: URL?
    private(set) var isChecking: Bool = false
    private(set) var lastCheckDate: Date?
    private(set) var error: String?

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return isNewer(latest, than: currentVersion)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private let owner = "iamsachin"
    private let repo = "cloom"

    init() {
        Task { await checkForUpdates() }
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        error = nil

        defer { isChecking = false }

        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Invalid response"
                return
            }

            if httpResponse.statusCode == 404 {
                // No releases yet
                lastCheckDate = Date()
                return
            }

            guard httpResponse.statusCode == 200 else {
                error = "GitHub API returned \(httpResponse.statusCode)"
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let tagVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            latestVersion = tagVersion
            lastCheckDate = Date()

            // Find .dmg asset URL
            if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                downloadURL = URL(string: dmgAsset.browserDownloadURL)
            } else {
                downloadURL = URL(string: release.htmlURL)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Compares two semantic version strings (e.g. "0.2.0" > "0.1.0").
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(candidateParts.count, currentParts.count) {
            let c = i < candidateParts.count ? candidateParts[i] : 0
            let o = i < currentParts.count ? currentParts[i] : 0
            if c > o { return true }
            if c < o { return false }
        }
        return false
    }

    private func isNewer(_ candidate: String, than current: String) -> Bool {
        Self.isNewer(candidate, than: current)
    }
}

// MARK: - GitHub API Models

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
