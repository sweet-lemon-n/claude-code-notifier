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
    @MainActor static func build(eventType: EventType,
                                  payload: HookPayload,
                                  settings: SettingsStore,
                                  summary: TranscriptSummary) -> Content {
        let projectName = payload.cwd.flatMap { (($0 as NSString).lastPathComponent) } ?? ""

        // ---- title -----------------------------------------------------------
        let title: String
        switch eventType {
        case .stop:
            title = LocaleManager.isChinese ? "Claude 已完成" : "Claude Finished"
        case .notification:
            title = LocaleManager.isChinese ? "需要确认" : "Action Required"
        case .codexStop:
            title = LocaleManager.isChinese ? "Codex 已完成" : "Codex Finished"
        }

        // ---- subtitle --------------------------------------------------------
        let subtitle: String
        switch eventType {
        case .stop, .codexStop:
            subtitle = projectName.isEmpty
                ? (LocaleManager.isChinese ? "任务完成" : "Task complete")
                : (LocaleManager.isChinese ? "\(projectName) 完成了" : "\(projectName) completed")
        case .notification:
            subtitle = projectName.isEmpty
                ? (LocaleManager.isChinese ? "Claude 正在等你确认" : "Claude is waiting for you")
                : (LocaleManager.isChinese ? "\(projectName) 正在等待确认" : "\(projectName) needs confirmation")
        }

        // ---- body ------------------------------------------------------------
        var parts: [String] = []

        switch eventType {
        case .notification:
            if let action = payload.actionSummary, !action.isEmpty {
                parts.append((LocaleManager.isChinese ? "待确认: " : "Confirm: ") + action)
            } else if let action = summary.pendingAction, !action.isEmpty {
                parts.append((LocaleManager.isChinese ? "待确认: " : "Confirm: ") + action)
            } else if settings.useClaudeMessageInNotif,
                      let msg = payload.message, !msg.isEmpty {
                parts.append(msg)
            }
        case .stop, .codexStop:
            if let action = summary.lastAction, !action.isEmpty {
                parts.append((LocaleManager.isChinese ? "完成: " : "Completed: ") + action)
            }
            if let message = payload.message, !message.isEmpty {
                parts.append(message)
            }
            if let completion = summary.completionSummary, !completion.isEmpty {
                parts.append((LocaleManager.isChinese ? "结果: " : "Result: ") + completion)
            }
            if let elapsed = summary.elapsedSeconds, elapsed > 0 {
                parts.append((LocaleManager.isChinese ? "用时: " : "Elapsed: ") + formatElapsed(elapsed))
            }
        }

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
        case .codexStop:
            return LocaleManager.isChinese
                ? "Codex 已完成任务。"
                : "Codex has finished the task."
        }
    }

    private static func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 {
            return LocaleManager.isChinese ? "\(total) 秒" : "\(total)s"
        }
        let minutes = total / 60
        let remainder = total % 60
        if minutes < 60 {
            return LocaleManager.isChinese
                ? "\(minutes) 分 \(remainder) 秒"
                : "\(minutes)m \(remainder)s"
        }
        let hours = minutes / 60
        return LocaleManager.isChinese
            ? "\(hours) 小时 \(minutes % 60) 分"
            : "\(hours)h \(minutes % 60)m"
    }
}
