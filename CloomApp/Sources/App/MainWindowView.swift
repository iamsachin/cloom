import SwiftUI
import SwiftData

// MARK: - Main Window View

struct MainWindowView: View {
    @State private var navigationState = NavigationState()
    @State private var sidebarSelection: SidebarSelection? = .allVideos

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(selection: $sidebarSelection)
        } detail: {
            detailContent
                .animation(.easeInOut(duration: 0.2), value: navigationState.currentMode)
        }
        .environment(navigationState)
        .onChange(of: sidebarSelection) { _, _ in
            if navigationState.isInEditor {
                navigationState.goBackToLibrary()
            }
        }
        .onKeyPress(.escape) {
            if navigationState.isInEditor {
                navigationState.goBack()
                return .handled
            }
            return .ignored
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch navigationState.currentMode {
        case .library:
            LibraryContentView(sidebarSelection: $sidebarSelection)
                .transition(.opacity)

        case .editor(let videoID):
            EditorContentView(videoID: videoID)
                .transition(.opacity)
        }
    }
}
