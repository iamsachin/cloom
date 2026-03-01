import UserNotifications

enum NotificationService {
    /// Post a local notification if the user has notifications enabled (defaults to true).
    static func post(title: String, body: String, categoryIdentifier: String? = nil) {
        let defaults = UserDefaults.standard
        // Default to enabled if the key has never been set
        if defaults.object(forKey: UserDefaultsKeys.notificationsEnabled) != nil,
           !defaults.bool(forKey: UserDefaultsKeys.notificationsEnabled) {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
