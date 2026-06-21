import Foundation

enum EventType: String, Codable, CaseIterable {
    case stop = "stop"
    case notification = "notification"
    case codexStop = "codex_stop"

    var displayName: String {
        switch self {
        case .stop: return LocaleManager.isChinese ? "Claude 完成" : "Claude Complete"
        case .notification: return LocaleManager.isChinese ? "需要确认" : "Needs Confirmation"
        case .codexStop: return LocaleManager.isChinese ? "Codex 完成" : "Codex Complete"
        }
    }

    var iconName: String {
        switch self {
        case .stop: return "checkmark.circle.fill"
        case .notification: return "bell.badge.fill"
        case .codexStop: return "chevron.left.forwardslash.chevron.right"
        }
    }

    var isConfirmation: Bool {
        self == .notification
    }
}
