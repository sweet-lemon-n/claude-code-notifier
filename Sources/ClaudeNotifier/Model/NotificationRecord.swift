import Foundation

/// Lightweight notification history entry for the menu bar UI
struct NotificationRecord: Identifiable, Codable {
    let id: UUID
    let eventType: EventType
    let title: String
    let message: String
    let projectPath: String?
    let time: Date

    init(eventType: EventType, title: String, message: String, projectPath: String?) {
        self.id = UUID()
        self.eventType = eventType
        self.title = title
        self.message = message
        self.projectPath = projectPath
        self.time = Date()
    }
}
