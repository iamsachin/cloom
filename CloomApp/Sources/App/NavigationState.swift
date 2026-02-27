import SwiftUI

// MARK: - Navigation State

@Observable
@MainActor
final class NavigationState {
    enum Mode: Equatable {
        case library
        case editor(videoID: String)
    }

    enum ViewStyle: String, CaseIterable {
        case grid, list
    }

    private(set) var currentMode: Mode = .library
    private var navigationStack: [String] = [] // videoID history

    var viewStyle: ViewStyle {
        didSet {
            UserDefaults.standard.set(viewStyle.rawValue, forKey: "libraryViewStyle")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "libraryViewStyle") ?? "grid"
        self.viewStyle = ViewStyle(rawValue: saved) ?? .grid
    }

    // MARK: - Navigation

    func openEditor(videoID: String) {
        navigationStack.append(videoID)
        currentMode = .editor(videoID: videoID)
    }

    func goBack() {
        navigationStack.removeLast()
        if let previous = navigationStack.last {
            currentMode = .editor(videoID: previous)
        } else {
            currentMode = .library
        }
    }

    func goBackToLibrary() {
        navigationStack.removeAll()
        currentMode = .library
    }

    var isInEditor: Bool {
        if case .editor = currentMode { return true }
        return false
    }

    var currentVideoID: String? {
        if case .editor(let id) = currentMode { return id }
        return nil
    }
}
