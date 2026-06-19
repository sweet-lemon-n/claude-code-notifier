import UserNotifications
import AppKit

/// Manages notification delivery using UNUserNotificationCenter.
/// Now that the app has a valid bundle identifier (com.sweetlemon.ClaudeNotifier)
/// and CFBundleIconFile, UN works reliably with our app icon.
final class NotificationManager: NSObject, ObservableObject {
    unowned let settings: SettingsStore

    /// Called when user clicks a notification — receives the project path.
    var onNotificationClicked: ((String) -> Void)?

    /// Map notification request ID → project path for click routing
    private var pending: [String: String] = [:]

    @Published var recentNotifications: [NotificationRecord] = []
    @Published var permissionGranted: Bool = false
    private let maxRecent = 10

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] s in
            if s.authorizationStatus == .authorized
                || s.authorizationStatus == .provisional {
                DispatchQueue.main.async {
                    self?.permissionGranted = true
                }
                return
            }
            // Not yet authorized — request it.
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                }
            }
        }
    }

    // MARK: - Send

    @MainActor func send(eventType: EventType, payload: HookPayload) {
        let built = NotificationContentBuilder.build(
            eventType: eventType, payload: payload, settings: settings
        )

        // Always record to history (menu bar shows these)
        record(eventType: eventType,
               title: built.title,
               message: built.body,
               projectPath: payload.cwd)

        // Build UN content
        let content = UNMutableNotificationContent()
        content.title = built.title
        if !built.subtitle.isEmpty {
            content.subtitle = built.subtitle
        }
        content.body = built.body
        content.sound = nil  // Sound handled by SoundManager
        content.interruptionLevel = .active
        content.categoryIdentifier = "CLAUDE_NOTIFIER"

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        if let path = payload.cwd, !path.isEmpty {
            pending[id] = path
        }

        UNUserNotificationCenter.current().add(request) { _ in
            // Even on error, history is recorded above
        }
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

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Always show the banner even when our app is "active" (menu bar always is).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    /// User clicked a notification — open the matching project in VSCode.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        if let path = pending[id] {
            DispatchQueue.main.async { [weak self] in
                self?.onNotificationClicked?(path)
            }
            pending.removeValue(forKey: id)
        }
        completionHandler()
    }
}
