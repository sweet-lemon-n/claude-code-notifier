import UserNotifications
import AppKit

/// Manages all notification lifecycle: permission, delivery, and click handling.
/// Uses UNUserNotificationCenter when authorized, falls back to osascript
/// for guaranteed delivery even without system permission.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    unowned let settings: SettingsStore

    var onNotificationClicked: ((String) -> Void)?

    private var pending: [String: String] = [:]
    private var unauthorized: Bool = true

    @Published var recentNotifications: [NotificationRecord] = []
    private let maxRecent = 10

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.unauthorized = false
                case .denied, .notDetermined:
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            self?.unauthorized = !granted
                        }
                    }
                @unknown default:
                    self?.unauthorized = true
                }
            }
        }
    }

    // MARK: - Send

    @MainActor func send(eventType: EventType, payload: HookPayload) {
        let built = NotificationContentBuilder.build(
            eventType: eventType, payload: payload, settings: settings
        )

        // Try UNUserNotificationCenter first
        if !unauthorized {
            sendViaUN(eventType: eventType, payload: payload, built: built)
        } else {
            // Fallback: osascript always works, no permission needed
            sendViaAppleScript(built: built, payload: payload)
        }

        // Always record history
        record(eventType: eventType,
               title: built.title,
               message: built.body,
               projectPath: payload.cwd)
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
            eventType: eventType, title: title,
            message: message, projectPath: projectPath
        )
        recentNotifications.insert(record, at: 0)
        if recentNotifications.count > maxRecent {
            recentNotifications = Array(recentNotifications.prefix(maxRecent))
        }
    }

    // MARK: - UN delivery

    @MainActor private func sendViaUN(eventType: EventType, payload: HookPayload,
                           built: NotificationContentBuilder.Content) {
        let content = UNMutableNotificationContent()
        content.title = built.title
        content.subtitle = built.subtitle
        content.body = built.body
        content.sound = settings.enableSound && !settings.muted
            ? notificationSound(for: eventType)
            : nil
        content.categoryIdentifier = "CLAUDE_NOTIFIER"
        content.interruptionLevel = .active

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let att = try? UNNotificationAttachment(identifier: "icon", url: iconURL, options: nil) {
            content.attachments = [att]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content, trigger: nil
        )
        pending[request.identifier] = payload.cwd

        UNUserNotificationCenter.current().add(request) { [weak self] _ in
            // Even if UN delivery reports an error, osascript fallback already ran
        }
    }

    // MARK: - osascript fallback

    @MainActor private func sendViaAppleScript(built: NotificationContentBuilder.Content,
                                     payload: HookPayload) {
        let soundName = settings.enableSound && !settings.muted
            ? "sound name \"Glass\"" : ""
        // Escape quotes for AppleScript
        let title = built.title.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let subtitle = built.subtitle.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let body = built.body.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = "display notification \"\(body)\" with title \"\(title)\" subtitle \"\(subtitle)\" \(soundName)"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    // MARK: - Helpers

    @MainActor private func notificationSound(for event: EventType) -> UNNotificationSound? {
        let name = settings.soundName(for: event)
        if name == "__custom__", !settings.customSoundPath.isEmpty {
            return UNNotificationSound(named: .init(rawValue: "Glass"))
        }
        return UNNotificationSound(named: .init(rawValue: name))
    }
}
