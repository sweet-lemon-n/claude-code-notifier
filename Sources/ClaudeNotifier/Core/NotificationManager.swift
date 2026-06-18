@preconcurrency import UserNotifications
import AppKit

/// Manages all notification lifecycle: permission, delivery, and click handling.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    unowned let settings: SettingsStore

    /// Called when the user clicks a notification. Parameter is the project path.
    var onNotificationClicked: ((String) -> Void)?

    /// Maps notification request ID → project path for click routing
    private var pending: [String: String] = [:]

    /// Ordered recent notification records for the menu bar
    @Published var recentNotifications: [NotificationRecord] = []
    private let maxRecent = 10

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("[ClaudeNotifier] Notification permission granted")
                } else if let error {
                    print("[ClaudeNotifier] Permission denied: \(error.localizedDescription)")
                }
            }
    }

    // MARK: - Send

    @MainActor func send(eventType: EventType, payload: HookPayload) {
        // Build smart content from hook data + user preferences
        let built = NotificationContentBuilder.build(
            eventType: eventType,
            payload: payload,
            settings: settings
        )

        let content = UNMutableNotificationContent()
        content.title = built.title
        content.subtitle = built.subtitle
        content.body = built.body
        content.sound = settings.enableSound && !settings.muted
            ? notificationSound(for: eventType)
            : nil
        content.categoryIdentifier = "CLAUDE_NOTIFIER"
        content.interruptionLevel = .active

        // Attach app icon
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let attachment = try? UNNotificationAttachment(
               identifier: "icon", url: iconURL, options: nil
           ) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        pending[request.identifier] = payload.cwd

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                print("[ClaudeNotifier] Failed to deliver: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self?.record(eventType: eventType,
                             title: content.title,
                             message: content.body,
                             projectPath: payload.cwd)
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        if let projectPath = pending[id] {
            onNotificationClicked?(projectPath)
            pending.removeValue(forKey: id)
        }
        completionHandler()
    }

    /// Always present notification even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    // MARK: - History

    private func record(eventType: EventType, title: String, message: String, projectPath: String?) {
        let record = NotificationRecord(
            eventType: eventType,
            title: title,
            message: message,
            projectPath: projectPath
        )
        recentNotifications.insert(record, at: 0)
        if recentNotifications.count > maxRecent {
            recentNotifications = Array(recentNotifications.prefix(maxRecent))
        }
    }

    // MARK: - Private helpers

    @MainActor private func notificationSound(for event: EventType) -> UNNotificationSound? {
        let name = settings.soundName(for: event)
        if name == "__custom__", !settings.customSoundPath.isEmpty {
            return UNNotificationSound(named: .init(rawValue: "Glass"))
        }
        return UNNotificationSound(named: .init(rawValue: name))
    }
}
