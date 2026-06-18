import Foundation

/// Builds rich, varied notification content from hook payload data and user preferences.
struct NotificationContentBuilder {

    /// Result with title, subtitle, and body.
    struct Content {
        let title: String
        let subtitle: String
        let body: String
    }

    /// Build notification content for a given event + payload.
    @MainActor static func build(eventType: EventType, payload: HookPayload, settings: SettingsStore) -> Content {
        let projectName = payload.cwd.flatMap { (($0 as NSString).lastPathComponent) } ?? ""

        // ---- title -----------------------------------------------------------
        let title = settings.effectiveTitle

        // ---- subtitle --------------------------------------------------------
        let subtitle = settings.effectiveSubtitle(for: eventType)

        // ---- body ------------------------------------------------------------
        var parts: [String] = []

        // Project name line (if enabled and available)
        if settings.showProjectNameInNotif, !projectName.isEmpty {
            parts.append(projectIcon + " " + projectName)
        }

        // Claude's own message (for Notification events where Claude says something)
        if settings.useClaudeMessageInNotif,
           let msg = payload.message, !msg.isEmpty,
           eventType == .notification {
            parts.append(msg)
        }

        // Timestamp line (if enabled)
        if settings.showTimestampInNotif {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: LocaleManager.isChinese ? "zh_CN" : "en_US")
            formatter.dateFormat = LocaleManager.isChinese ? "HH:mm:ss" : "h:mm:ss a"
            parts.append(timeIcon + " " + formatter.string(from: Date()))
        }

        // If we still have nothing, use a generic fallback
        let body = parts.isEmpty
            ? genericMessage(for: eventType)
            : parts.joined(separator: "\n")

        return Content(title: title, subtitle: subtitle, body: body)
    }

    // MARK: - Helpers

    private static var projectIcon: String {
        LocaleManager.isChinese ? "📁" : "📁"
    }

    private static var timeIcon: String {
        LocaleManager.isChinese ? "🕐" : "🕐"
    }

    private static func genericMessage(for eventType: EventType) -> String {
        switch eventType {
        case .stop:
            return LocaleManager.isChinese
                ? "Claude 已完成任务，等待你的下一步指令。"
                : "Claude has finished — awaiting your next instruction."
        case .notification:
            return LocaleManager.isChinese
                ? "Claude 需要你确认一个操作。"
                : "Claude needs your confirmation."
        }
    }
}
