import Foundation

/// Incoming JSON payload from the Claude Code hook, forwarded by notify.sh
struct HookPayload: Codable {
    let event: EventType
    let cwd: String?
    let message: String?
    let sessionId: String?
    let transcriptPath: String?
    let notifierScriptReceivedAt: TimeInterval?
    let notifierSourceEvent: String?
    let actionSummary: String?

    enum CodingKeys: String, CodingKey {
        case event, cwd, message
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case notifierScriptReceivedAt = "notifier_script_received_at"
        case notifierSourceEvent = "notifier_source_event"
        case actionSummary = "action_summary"
    }
}
