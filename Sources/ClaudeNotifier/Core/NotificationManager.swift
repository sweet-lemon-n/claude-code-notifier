import UserNotifications
import AppKit

/// Standard macOS notifications via UNUserNotificationCenter.
final class NotificationManager: NSObject, ObservableObject {
    unowned let settings: SettingsStore

    /// Click-to-VSCode callback — receives the project path.
    var onNotificationClicked: ((String) -> Void)?

    /// Maps notification ID → project path.
    private var pending: [String: String] = [:]

    @Published var recentNotifications: [NotificationRecord] = []
    private let maxRecent = 10

    /// Dedup: skip repeated hook deliveries within this window.
    private var recentlySent: [String: Date] = [:]
    private let duplicateWindow: TimeInterval = 5

    init(settings: SettingsStore) {
        self.settings = settings
        super.init()

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let confirmAction = UNNotificationAction(
            identifier: "OPEN_PROJECT",
            title: LocaleManager.isChinese ? "去确认" : "Review",
            options: .foreground
        )
        let openAction = UNNotificationAction(
            identifier: "OPEN_PROJECT",
            title: LocaleManager.isChinese ? "打开项目" : "Open Project",
            options: .foreground
        )
        let confirmationCategory = UNNotificationCategory(
            identifier: "CLAUDE_NOTIFIER_CONFIRM",
            actions: [confirmAction],
            intentIdentifiers: [],
            options: []
        )
        let completionCategory = UNNotificationCategory(
            identifier: "CLAUDE_NOTIFIER_DONE",
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([confirmationCategory, completionCategory])
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error {
                print("[CodeNotifier] UN auth error: \(error)")
            } else {
                print("[CodeNotifier] UN auth granted: \(granted)")
            }
        }
    }

    // MARK: - Send

    @MainActor func send(eventType: EventType, payload: HookPayload) {
        let now = Date()

        pruneRecentlySent(now: now)
        let key = deduplicationKey(eventType: eventType, payload: payload)
        if let lastTime = recentlySent[key],
           now.timeIntervalSince(lastTime) < duplicateWindow {
            return
        }
        recentlySent[key] = now

        let summary = TranscriptSummarizer.summarize(path: payload.transcriptPath)
        let built = NotificationContentBuilder.build(
            eventType: eventType,
            payload: payload,
            settings: settings,
            summary: summary
        )

        record(eventType: eventType,
               title: built.title,
               message: built.body,
               projectPath: payload.cwd)

        let content = UNMutableNotificationContent()
        content.title = built.title
        content.subtitle = built.subtitle
        content.body = built.body
        content.sound = .default
        content.categoryIdentifier = eventType.isConfirmation
            ? "CLAUDE_NOTIFIER_CONFIRM"
            : "CLAUDE_NOTIFIER_DONE"
        content.interruptionLevel = .active
        if eventType.isConfirmation {
            content.threadIdentifier = "code-notifier-confirmation"
        } else {
            content.threadIdentifier = eventType == .codexStop
                ? "code-notifier-codex-completion"
                : "code-notifier-claude-completion"
        }
        if let attachment = notificationAttachment(for: eventType) {
            content.attachments = [attachment]
        }

        let id = UUID().uuidString
        if let path = payload.cwd, !path.isEmpty {
            pending[id] = path
            content.userInfo = ["cwd": path]
        }

        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[CodeNotifier] deliver error: \(error)")
            }
        }

        logLatency(eventType: eventType, payload: payload)
    }

    // MARK: - History

    private func record(eventType: EventType, title: String,
                        message: String, projectPath: String?) {
        let record = NotificationRecord(
            eventType: eventType, title: title,
            message: message, projectPath: projectPath
        )
        recentNotifications.insert(record, at: 0)
        if recentNotifications.count > maxRecent {
            recentNotifications = Array(recentNotifications.prefix(maxRecent))
        }
    }

    private func deduplicationKey(eventType: EventType, payload: HookPayload) -> String {
        [
            eventType.rawValue,
            payload.cwd ?? "",
            payload.sessionId ?? "",
            payload.actionSummary ?? "",
            payload.message ?? ""
        ].joined(separator: "\u{1f}")
    }

    private func pruneRecentlySent(now: Date) {
        recentlySent = recentlySent.filter {
            now.timeIntervalSince($0.value) < duplicateWindow
        }
    }

    private func logLatency(eventType: EventType, payload: HookPayload) {
        guard let scriptReceived = payload.notifierScriptReceivedAt else { return }
        let now = Date().timeIntervalSince1970
        let ipcDelay = max(0, now - scriptReceived)
        let source = payload.notifierSourceEvent ?? eventType.rawValue
        let line = "[CodeNotifier] \(eventType.rawValue)(source=\(source)) hook-to-app delay: \(String(format: "%.3f", ipcDelay))s"
        print(line)
        appendLatencyLog(line)
    }

    private func appendLatencyLog(_ line: String) {
        let path = "\(NSHomeDirectory())/.claude/claude-notifier-latency.log"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let entry = "\(formatter.string(from: Date())) \(line)\n"
        guard let data = entry.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    private func notificationAttachment(for eventType: EventType) -> UNNotificationAttachment? {
        let name = eventType.isConfirmation ? "ConfirmNotification" : "DoneNotification"
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        return try? UNNotificationAttachment(identifier: name, url: url)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// User clicked the notification (or the "Open Project" action button) →
    /// open the project in VSCode.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let path = pending[id]
            ?? (response.notification.request.content.userInfo["cwd"] as? String)
        if let path {
            DispatchQueue.main.async { [weak self] in
                self?.onNotificationClicked?(path)
            }
            pending.removeValue(forKey: id)
        }
        completionHandler()
    }
}
