import Combine
@preconcurrency import Sparkle

/// Wraps Sparkle's `SPUStandardUpdaterController` for SwiftUI integration.
/// Shared as an `@EnvironmentObject` across Settings and MenuBar views.
@MainActor
final class SparkleUpdater: ObservableObject {
    let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    private var cancellable: AnyCancellable?
    private let driverDelegate = GentleReminderDelegate()

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: driverDelegate
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

/// Enables Sparkle's gentle reminder feature — shows a subtle update notice
/// instead of a full modal dialog for background update checks.
final class GentleReminderDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {}

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Show the update UI even when the app is not in immediate focus
        true
    }
}
