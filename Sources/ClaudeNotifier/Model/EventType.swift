import Foundation

enum EventType: String, Codable, CaseIterable {
    case stop = "stop"
    case notification = "notification"

    var displayName: String {
        switch self {
        case .stop: return "Task Complete"
        case .notification: return "Needs Confirmation"
        }
    }

    var iconName: String {
        switch self {
        case .stop: return "checkmark.circle.fill"
        case .notification: return "bell.badge.fill"
        }
    }
}
