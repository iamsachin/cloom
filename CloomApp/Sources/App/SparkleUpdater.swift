import Combine
@preconcurrency import Sparkle

/// Wraps Sparkle's `SPUStandardUpdaterController` for SwiftUI integration.
/// Shared as an `@EnvironmentObject` across Settings and MenuBar views.
@MainActor
final class SparkleUpdater: ObservableObject {
    let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    private var cancellable: AnyCancellable?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        cancellable = updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCheck in
                self?.canCheckForUpdates = canCheck
            }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
