import AppKit

/// Manages notification delivery and click handling.
/// Uses NSUserNotificationCenter — reliable, no permission dialog needed,
/// supports click actions, works with LSUIElement apps.
///
/// UNUserNotificationCenter is NOT used because LSUIElement menu-bar apps
/// cannot reliably obtain notification permission from macOS.
final class NotificationManager: NSObject, NSUserNotificationCenterDelegate, ObservableObject {
    unowned let settings: SettingsStore

    var onNotificationClicked: ((String) -> Void)?

    /// Maps notification identifier → project path for click routing
    private var pending: [String: String] = [:]

    @Published var recentNotifications: [NotificationRecord] = []
    private let maxRecent = 10

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        NSUserNotificationCenter.default.delegate = self
    }

    // No permission request needed — NSUserNotificationCenter works without it.

    // MARK: - Send

    @MainActor func send(eventType: EventType, payload: HookPayload) {
        let built = NotificationContentBuilder.build(
            eventType: eventType, payload: payload, settings: settings
        )

        let note = NSUserNotification()
        note.identifier = UUID().uuidString
        note.title = built.title
        note.subtitle = built.subtitle
        note.informativeText = built.body
        // Sound is handled by SoundManager separately — no soundName here
        note.hasActionButton = true
        note.actionButtonTitle = LocaleManager.isChinese ? "打开项目" : "Open Project"
        note.otherButtonTitle = LocaleManager.isChinese ? "关闭" : "Close"
        note.userInfo = ["cwd": payload.cwd ?? NSNull()]

        pending[note.identifier!] = payload.cwd

        NSUserNotificationCenter.default.deliver(note)

        record(eventType: eventType,
               title: built.title,
               message: built.body,
               projectPath: payload.cwd)
    }

    // MARK: - NSUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        didActivate notification: NSUserNotification
    ) {
        guard let identifier = notification.identifier,
              let projectPath = pending[identifier] else { return }

        switch notification.activationType {
        case .actionButtonClicked, .contentsClicked:
            onNotificationClicked?(projectPath)
        default:
            break
        }
        pending.removeValue(forKey: identifier)
    }

    /// Always show even when app is active (menu bar app is always "active").
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        true
    }

    // MARK: - History

    private func record(eventType: EventType, title: String, message: String, projectPath: String?) {
        let record = NotificationRecord(
            eventType: eventType, title: title,
            message: message, projectPath: projectPath
        )
        recentNotifications.insert(record, at: 0)
        if recentNotifications.count > maxRecent {
            recentNotifications = Array(recentNotifications.prefix(maxRecent))
        }
    }
}
