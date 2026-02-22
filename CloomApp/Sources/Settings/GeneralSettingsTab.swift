import SwiftUI
import ServiceManagement

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

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
        }
        .formStyle(.grouped)
    }
}
