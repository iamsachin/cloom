import SwiftUI

struct ToolbarToggleButton: View {
    let icon: String
    var offIcon: String?
    let isActive: Bool
    var activeColor: Color = .white
    var offColor: Color = .white
    var help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isActive ? icon : (offIcon ?? icon))
                .foregroundStyle(isActive ? activeColor : offColor)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
