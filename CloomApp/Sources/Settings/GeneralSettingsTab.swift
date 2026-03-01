import SwiftUI
import LaunchAtLogin

struct GeneralSettingsTab: View {
    @AppStorage(UserDefaultsKeys.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(UserDefaultsKeys.appearanceMode) private var appearanceMode: String = "system"
    @EnvironmentObject var permissionChecker: PermissionChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            LaunchAtLogin.Toggle()

            Toggle("Show Notifications", isOn: $notificationsEnabled)

            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceMode) { _, newValue in
                switch newValue {
                case "light": NSApp.appearance = NSAppearance(named: .aqua)
                case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
                default: NSApp.appearance = nil
                }
            }

            Section("Permissions & Setup") {
                ForEach(PermissionKind.allCases) { kind in
                    HStack {
                        Image(systemName: permissionChecker.statuses[kind] == true
                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(permissionChecker.statuses[kind] == true ? .green : .red)

                        Text(kind.displayName)

                        if kind.isOptional {
                            Text("Optional")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }

                        Spacer()

                        if permissionChecker.statuses[kind] != true {
                            Button("Grant") {
                                permissionChecker.requestPermission(kind)
                            }
                            .controlSize(.small)
                        }
                    }
                }

                Button("Re-open Welcome Setup...") {
                    NSApp.activate()
                    openWindow(id: "onboarding")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissionChecker.checkAll()
        }
    }
}
